package tunnel

import (
	"bytes"
	"crypto/tls"
	"errors"
	"fmt"
	"io"
	"net"
	"strings"
	"time"

	"golang.org/x/crypto/ssh"
)

type SshTunnelClient struct {
	rawConn net.Conn
	client  *ssh.Client
}

// PrefixedConn allows reading the already-buffered SSH banner bytes followed by normal socket IO.
type PrefixedConn struct {
	net.Conn
	reader io.Reader
}

func (p *PrefixedConn) Read(b []byte) (int, error) {
	return p.reader.Read(b)
}

func ConnectSsh(cfg SshConfig, logger func(string, string)) (*SshTunnelClient, error) {
	useProxy := cfg.Proxy != nil && cfg.Proxy.Enabled && cfg.Proxy.Host != ""
	connectHost := cfg.Host
	connectPort := cfg.Port
	if useProxy {
		connectHost = cfg.Proxy.Host
		if cfg.Proxy.Port > 0 {
			connectPort = cfg.Proxy.Port
		}
	}

	logger("CONFIG", fmt.Sprintf("Hôte: %s:%d | TLS: %v", cfg.Host, cfg.Port, cfg.TLS))
	if useProxy {
		logger("PROXY", fmt.Sprintf("Proxy: %s:%d", connectHost, connectPort))
	}

	dest := fmt.Sprintf("%s:%d", connectHost, connectPort)
	dialer := net.Dialer{Timeout: 10 * time.Second}
	rawConn, err := dialer.Dial("tcp", dest)
	if err != nil {
		return nil, fmt.Errorf("échec de connexion à %s: %w", dest, err)
	}

	var activeConn net.Conn = rawConn

	if cfg.TLS {
		sniHost := cfg.SNI
		if sniHost == "" {
			sniHost = cfg.Host
		}
		tlsConfig := &tls.Config{
			ServerName:         sniHost,
			InsecureSkipVerify: true,
		}
		tlsConn := tls.Client(rawConn, tlsConfig)
		if err := tlsConn.Handshake(); err != nil {
			rawConn.Close()
			return nil, fmt.Errorf("échec poignée de main TLS: %w", err)
		}
		activeConn = tlsConn
	}

	// Inject payload if specified
	if cfg.Payload != "" {
		formattedPayload := ReplaceMacros(
			cfg.Payload,
			cfg.Host,
			cfg.Port,
			connectHost,
			connectPort,
			cfg.SNI,
		)
		logger("PAYLOAD", fmt.Sprintf("Injection de %d octets...", len(formattedPayload)))
		if _, err := activeConn.Write([]byte(formattedPayload)); err != nil {
			activeConn.Close()
			return nil, fmt.Errorf("erreur envoi payload: %w", err)
		}

		// Wait for SSH banner or HTTP 200/101
		prefix, err := waitForSshBanner(activeConn, logger)
		if err != nil {
			activeConn.Close()
			return nil, err
		}
		activeConn = &PrefixedConn{
			Conn:   activeConn,
			reader: io.MultiReader(bytes.NewReader(prefix), activeConn),
		}
	}

	// Authenticate SSH
	sshConfig := &ssh.ClientConfig{
		User: cfg.Username,
		Auth: []ssh.AuthMethod{
			ssh.Password(cfg.Password),
			ssh.KeyboardInteractive(func(user, instruction string, questions []string, echos []bool) (answers []string, err error) {
				answers = make([]string, len(questions))
				for i := range questions {
					answers[i] = cfg.Password
				}
				return answers, nil
			}),
		},
		HostKeyCallback: ssh.InsecureIgnoreHostKey(),
		Timeout:         15 * time.Second,
	}

	logger("SSH", fmt.Sprintf("Authentification de '%s'...", cfg.Username))
	sshConn, chans, reqs, err := ssh.NewClientConn(activeConn, dest, sshConfig)
	if err != nil {
		activeConn.Close()
		return nil, fmt.Errorf("authentification SSH refusée: %w", err)
	}
	client := ssh.NewClient(sshConn, chans, reqs)
	logger("SUCCESS", "Liaison SSH établie avec succès !")

	// Keepalive ticker
	go func() {
		ticker := time.NewTicker(15 * time.Second)
		defer ticker.Stop()
		for range ticker.C {
			_, _, err := client.SendRequest("keepalive@openssh.com", true, nil)
			if err != nil {
				return
			}
		}
	}()

	return &SshTunnelClient{
		rawConn: activeConn,
		client:  client,
	}, nil
}

func waitForSshBanner(conn net.Conn, logger func(string, string)) ([]byte, error) {
	_ = conn.SetReadDeadline(time.Now().Add(12 * time.Second))
	defer conn.SetReadDeadline(time.Time{})

	buf := make([]byte, 4096)
	var accumulated bytes.Buffer

	for {
		n, err := conn.Read(buf)
		if n > 0 {
			accumulated.Write(buf[:n])
			str := accumulated.String()

			// Check for SSH-2.0 or SSH-1.99
			if idx := strings.Index(str, "SSH-"); idx >= 0 && (strings.Contains(str, "SSH-2.0") || strings.Contains(str, "SSH-1.99")) {
				lines := strings.Split(str[idx:], "\n")
				logger("RESPONSE", strings.TrimSpace(lines[0]))
				return accumulated.Bytes()[idx:], nil
			}

			// Check for HTTP headers (e.g. HTTP/1.1 200 or 101)
			if strings.Contains(str, "\r\n\r\n") {
				headerEnd := strings.Index(str, "\r\n\r\n") + 4
				headerBlock := str[:headerEnd]
				lines := strings.Split(headerBlock, "\r\n")
				statusLine := lines[0]
				logger("RESPONSE", statusLine)
				if strings.Contains(statusLine, " 101 ") || strings.Contains(statusLine, " 200 ") {
					return accumulated.Bytes()[headerEnd:], nil
				}
			}
		}
		if err != nil {
			return nil, errors.New("délai dépassé ou connexion rompue en attente de la bannière SSH")
		}
	}
}

func (s *SshTunnelClient) Close() {
	if s.client != nil {
		_ = s.client.Close()
	}
	if s.rawConn != nil {
		_ = s.rawConn.Close()
	}
}
