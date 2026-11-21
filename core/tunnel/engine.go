package tunnel

import (
	"errors"
	"fmt"
	"sync"
	"time"
)

type Engine struct {
	mu           sync.Mutex
	state        string
	startTime    time.Time
	sshClient    *SshTunnelClient
	socksServer  *Socks5Server
	dnsResolver  *DnsResolver
	tunCloser    interface{ Close() }
	logs         []string
	errorMessage string
	lastTx       int64
	lastRx       int64
}

func NewEngine() *Engine {
	return &Engine{
		state: "DISCONNECTED",
		logs:  make([]string, 0, 100),
	}
}

func (e *Engine) Log(tag, message string) {
	e.mu.Lock()
	defer e.mu.Unlock()
	entry := fmt.Sprintf("[%s] [%s] %s", time.Now().Format("15:04:05"), tag, message)
	e.logs = append(e.logs, entry)
	if len(e.logs) > 100 {
		e.logs = e.logs[len(e.logs)-100:]
	}
}

func (e *Engine) Start(cfg TunnelConfig) error {
	e.mu.Lock()
	if e.state == "CONNECTING" || e.state == "CONNECTED" {
		e.mu.Unlock()
		return errors.New("tunnel déjà actif ou en cours de connexion")
	}
	e.state = "CONNECTING"
	e.errorMessage = ""
	e.mu.Unlock()

	e.Log("INIT", "Initialisation de la connexion Surfeo Secure Tunnel...")

	if cfg.Type != "ssh" || cfg.SSH == nil {
		e.setError("Configuration de tunnel invalide (SSH requis)")
		return errors.New("configuration SSH invalide")
	}

	// 1. Establish SSH connection & inject HTTP payload
	sshClient, err := ConnectSsh(*cfg.SSH, e.Log)
	if err != nil {
		e.setError(err.Error())
		return err
	}

	// 2. Setup DNS Resolver with AAAA NODATA filter & TCP fallback
	dnsResolver := NewDnsResolver(sshClient.client)

	// 3. Start local SOCKS5 server on 127.0.0.1:10808
	socksServer := NewSocks5Server(10808, sshClient.client, dnsResolver)
	if err := socksServer.Start(); err != nil {
		sshClient.Close()
		e.setError(fmt.Sprintf("Échec de démarrage du serveur SOCKS5: %v", err))
		return err
	}
	e.Log("SUCCESS", "Serveur SOCKS5 local actif sur 127.0.0.1:10808")

	// 4. Setup Virtual TUN Adapter (Wintun on Windows, /dev/net/tun on Linux)
	tunDev, err := SetupTunDevice(cfg.SSH.Host, e.Log)
	if err != nil {
		socksServer.Stop()
		sshClient.Close()
		e.setError(fmt.Sprintf("Échec de configuration du réseau virtuel: %v", err))
		return err
	}

	e.mu.Lock()
	e.sshClient = sshClient
	e.socksServer = socksServer
	e.dnsResolver = dnsResolver
	e.tunCloser = tunDev
	e.state = "CONNECTED"
	e.startTime = time.Now()
	e.mu.Unlock()

	e.Log("SUCCESS", "Connexion sécurisée établie avec succès !")
	return nil
}

func (e *Engine) Stop() {
	e.mu.Lock()
	defer e.mu.Unlock()

	if e.state == "DISCONNECTED" {
		return
	}
	e.state = "DISCONNECTED"

	if e.tunCloser != nil {
		e.tunCloser.Close()
		e.tunCloser = nil
	}
	if e.socksServer != nil {
		e.socksServer.Stop()
		e.socksServer = nil
	}
	if e.sshClient != nil {
		e.sshClient.Close()
		e.sshClient = nil
	}
	e.Log("INFO", "Tunnel déconnecté.")
}

func (e *Engine) setError(msg string) {
	e.mu.Lock()
	defer e.mu.Unlock()
	e.state = "ERROR"
	e.errorMessage = msg
	e.Log("ERROR", msg)
}

func (e *Engine) GetStats() TunnelStats {
	e.mu.Lock()
	defer e.mu.Unlock()

	var duration int64 = 0
	if e.state == "CONNECTED" && !e.startTime.IsZero() {
		duration = int64(time.Since(e.startTime).Seconds())
	}

	var curTx, curRx int64 = 0, 0
	if e.socksServer != nil {
		curTx, curRx = e.socksServer.Stats()
	}

	txRate := curTx - e.lastTx
	rxRate := curRx - e.lastRx
	if txRate < 0 {
		txRate = 0
	}
	if rxRate < 0 {
		rxRate = 0
	}
	e.lastTx = curTx
	e.lastRx = curRx

	return TunnelStats{
		State:           e.state,
		DurationSeconds: duration,
		TxBytes:         curTx,
		RxBytes:         curRx,
		TxRateBps:       txRate,
		RxRateBps:       rxRate,
		ErrorMessage:    e.errorMessage,
	}
}

func (e *Engine) GetLogs() []string {
	e.mu.Lock()
	defer e.mu.Unlock()
	copied := make([]string, len(e.logs))
	copy(copied, e.logs)
	return copied
}
