package tunnel

import (
	"encoding/binary"
	"fmt"
	"io"
	"net"
	"sync"
	"sync/atomic"

	"golang.org/x/crypto/ssh"
)

type Socks5Server struct {
	port       int
	sshClient  *ssh.Client
	listener   net.Listener
	dns        *DnsResolver
	running    atomic.Bool
	txBytes    atomic.Int64
	rxBytes    atomic.Int64
	activeCons sync.Map
}

func NewSocks5Server(port int, client *ssh.Client, dns *DnsResolver) *Socks5Server {
	return &Socks5Server{
		port:      port,
		sshClient: client,
		dns:       dns,
	}
}

func (s *Socks5Server) Start() error {
	ln, err := net.Listen("tcp", fmt.Sprintf("127.0.0.1:%d", s.port))
	if err != nil {
		return err
	}
	s.listener = ln
	s.running.Store(true)

	go s.acceptLoop()
	return nil
}

func (s *Socks5Server) Stop() {
	s.running.Store(false)
	if s.listener != nil {
		_ = s.listener.Close()
	}
	s.activeCons.Range(func(key, value any) bool {
		if c, ok := key.(io.Closer); ok {
			_ = c.Close()
		}
		return true
	})
}

func (s *Socks5Server) Stats() (int64, int64) {
	return s.txBytes.Load(), s.rxBytes.Load()
}

func (s *Socks5Server) acceptLoop() {
	for s.running.Load() {
		conn, err := s.listener.Accept()
		if err != nil {
			if !s.running.Load() {
				break
			}
			continue
		}
		go s.handleClient(conn)
	}
}

func (s *Socks5Server) handleClient(conn net.Conn) {
	s.activeCons.Store(conn, struct{}{})
	defer func() {
		_ = conn.Close()
		s.activeCons.Delete(conn)
	}()

	// 1. Handshake (RFC 1928)
	buf := make([]byte, 256)
	if _, err := io.ReadFull(conn, buf[:2]); err != nil || buf[0] != 0x05 {
		return
	}
	nMethods := int(buf[1])
	if _, err := io.ReadFull(conn, buf[:nMethods]); err != nil {
		return
	}
	// NO_AUTH
	if _, err := conn.Write([]byte{0x05, 0x00}); err != nil {
		return
	}

	// 2. Request
	if _, err := io.ReadFull(conn, buf[:4]); err != nil || buf[0] != 0x05 {
		return
	}
	cmd := buf[1]
	atyp := buf[3]

	var targetHost string
	switch atyp {
	case 0x01: // IPv4
		if _, err := io.ReadFull(conn, buf[:4]); err != nil {
			return
		}
		targetHost = net.IP(buf[:4]).String()
	case 0x03: // Domain
		if _, err := io.ReadFull(conn, buf[:1]); err != nil {
			return
		}
		dLen := int(buf[0])
		if _, err := io.ReadFull(conn, buf[:dLen]); err != nil {
			return
		}
		targetHost = string(buf[:dLen])
	case 0x04: // IPv6
		if _, err := io.ReadFull(conn, buf[:16]); err != nil {
			return
		}
		targetHost = net.IP(buf[:16]).String()
	default:
		_, _ = conn.Write([]byte{0x05, 0x08, 0x00, 0x01, 0, 0, 0, 0, 0, 0})
		return
	}

	if _, err := io.ReadFull(conn, buf[:2]); err != nil {
		return
	}
	targetPort := binary.BigEndian.Uint16(buf[:2])

	switch cmd {
	case 0x01: // CONNECT
		dest := fmt.Sprintf("%s:%d", targetHost, targetPort)
		remoteConn, err := s.sshClient.Dial("tcp", dest)
		if err != nil {
			_, _ = conn.Write([]byte{0x05, 0x05, 0x00, 0x01, 0, 0, 0, 0, 0, 0})
			return
		}
		defer remoteConn.Close()

		_, _ = conn.Write([]byte{0x05, 0x00, 0x00, 0x01, 127, 0, 0, 1, byte(s.port >> 8), byte(s.port & 0xFF)})

		// Pipe bidirectional traffic
		var wg sync.WaitGroup
		wg.Add(2)
		go func() {
			defer wg.Done()
			n, _ := io.Copy(remoteConn, conn)
			s.txBytes.Add(n)
			if tc, ok := remoteConn.(interface{ CloseWrite() error }); ok {
				_ = tc.CloseWrite()
			}
		}()
		go func() {
			defer wg.Done()
			n, _ := io.Copy(conn, remoteConn)
			s.rxBytes.Add(n)
			if tc, ok := conn.(interface{ CloseWrite() error }); ok {
				_ = tc.CloseWrite()
			}
		}()
		wg.Wait()

	case 0x03: // UDP ASSOCIATE
		udpListener, err := net.ListenUDP("udp", &net.UDPAddr{IP: net.ParseIP("127.0.0.1"), Port: 0})
		if err != nil {
			_, _ = conn.Write([]byte{0x05, 0x01, 0x00, 0x01, 0, 0, 0, 0, 0, 0})
			return
		}
		defer udpListener.Close()

		localAddr := udpListener.LocalAddr().(*net.UDPAddr)
		portHi := byte(localAddr.Port >> 8)
		portLo := byte(localAddr.Port & 0xFF)
		_, _ = conn.Write([]byte{0x05, 0x00, 0x00, 0x01, 127, 0, 0, 1, portHi, portLo})

		go s.handleUdpLoop(udpListener)

		// Wait until TCP connection closes to teardown UDP associate
		dummy := make([]byte, 128)
		for {
			if _, err := conn.Read(dummy); err != nil {
				break
			}
		}
	}
}

func (s *Socks5Server) handleUdpLoop(u *net.UDPConn) {
	buf := make([]byte, 65536)
	for s.running.Load() {
		n, clientAddr, err := u.ReadFrom(buf)
		if err != nil {
			break
		}
		if n < 10 {
			continue
		}
		data := buf[:n]
		if data[2] != 0 { // Fragment
			continue
		}

		atyp := data[3]
		headerLen := 4
		switch atyp {
		case 0x01: // IPv4
			headerLen += 4
		case 0x03: // Domain
			headerLen += 1 + int(data[4])
		case 0x04: // IPv6
			headerLen += 16
		default:
			continue
		}
		if headerLen+2 > n {
			continue
		}
		dstPort := binary.BigEndian.Uint16(data[headerLen : headerLen+2])
		headerLen += 2

		payload := data[headerLen:]

		// QUIC UDP 443 Drop (forces TCP fallback for Google/YouTube)
		if dstPort == 443 {
			continue
		}

		// DNS UDP 53
		if dstPort == 53 && s.dns != nil {
			go func(q []byte, h []byte, cl net.Addr) {
				resp := s.dns.Resolve(q)
				if resp != nil {
					out := append(h, resp...)
					_, _ = u.WriteTo(out, cl)
					s.rxBytes.Add(int64(len(out)))
				}
			}(payload, data[:headerLen], clientAddr)
		}
	}
}
