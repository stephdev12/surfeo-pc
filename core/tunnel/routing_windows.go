//go:build windows

package tunnel

import (
	"fmt"
	"net"
	"os/exec"
	"strings"
	"syscall"

	"golang.zx2c4.com/wintun"
)

type WindowsTunDevice struct {
	adapter *wintun.Adapter
	session wintun.Session
	vpsIp   string
	gwIp    string
}

func SetupTunDevice(vpsHost string, logger func(string, string)) (*WindowsTunDevice, error) {
	// 1. Resolve VPS IP address
	ips, err := net.LookupIP(vpsHost)
	if err != nil || len(ips) == 0 {
		return nil, fmt.Errorf("impossible de résoudre l'adresse IP du serveur VPS: %v", err)
	}
	vpsIp := ips[0].String()

	// 2. Determine default physical gateway IP
	gwIp := getDefaultGateway()
	if gwIp == "" {
		logger("WARN", "Passerelle physique par défaut introuvable, utilisation de la passerelle système.")
	} else {
		logger("NET", fmt.Sprintf("Passerelle physique détectée : %s", gwIp))
	}

	// 3. Create Wintun adapter
	wintun.SetLogger(func(level wintun.LogLevel, timestamp uint64, msg string) {
		// Suppress verbose driver logs
	})

	adapter, err := wintun.CreateAdapter("Surfeo Secure Tunnel", "Wintun", nil)
	if err != nil {
		// If already exists, open it
		adapter, err = wintun.OpenAdapter("Surfeo Secure Tunnel")
		if err != nil {
			return nil, fmt.Errorf("échec de création de l'adaptateur virtuel Wintun: %w", err)
		}
	}

	session, err := adapter.StartSession(0x800000) // 8MB ring buffer
	if err != nil {
		adapter.Close()
		return nil, fmt.Errorf("échec d'initialisation de la session Wintun: %w", err)
	}

	dev := &WindowsTunDevice{
		adapter: adapter,
		session: session,
		vpsIp:   vpsIp,
		gwIp:    gwIp,
	}

	// 4. Configure IP address on Wintun adapter
	adapterName := "Surfeo Secure Tunnel"
	runCmd("netsh", "interface", "ipv4", "set", "address", fmt.Sprintf("name=\"%s\"", adapterName), "static", "26.26.26.1", "255.255.255.0", "none")
	runCmd("netsh", "interface", "ipv4", "set", "subinterface", fmt.Sprintf("name=\"%s\"", adapterName), "mtu=1400", "store=persistent")
	runCmd("netsh", "interface", "ipv4", "set", "dns", fmt.Sprintf("name=\"%s\"", adapterName), "static", "1.1.1.1", "primary")
	runCmd("netsh", "interface", "ipv4", "add", "dns", fmt.Sprintf("name=\"%s\"", adapterName), "1.0.0.1", "index=2")

	// 5. Bypass route for VPS IP via physical gateway (prevents routing loop)
	if gwIp != "" && vpsIp != "" {
		runCmd("route", "add", vpsIp, "mask", "255.255.255.255", gwIp, "metric", "1")
	}

	// 6. Direct all Internet traffic into TUN using 0/1 and 128/1 trick
	runCmd("route", "add", "0.0.0.0", "mask", "128.0.0.0", "26.26.26.1", "metric", "5")
	runCmd("route", "add", "128.0.0.0", "mask", "128.0.0.0", "26.26.26.1", "metric", "5")

	logger("SUCCESS", "Interface virtuelle Wintun active et routage configuré.")
	return dev, nil
}

func (w *WindowsTunDevice) Close() {
	if w.vpsIp != "" && w.gwIp != "" {
		runCmd("route", "delete", w.vpsIp)
	}
	runCmd("route", "delete", "0.0.0.0", "mask", "128.0.0.0", "26.26.26.1")
	runCmd("route", "delete", "128.0.0.0", "mask", "128.0.0.0", "26.26.26.1")

	if w.session != 0 {
		_ = w.session.End()
	}
	if w.adapter != nil {
		_ = w.adapter.Close()
	}
}

func getDefaultGateway() string {
	out, err := exec.Command("route", "print", "0.0.0.0").Output()
	if err != nil {
		return ""
	}
	lines := strings.Split(string(out), "\n")
	for _, line := range lines {
		fields := strings.Fields(line)
		if len(fields) >= 5 && fields[0] == "0.0.0.0" && fields[1] == "0.0.0.0" {
			return fields[2]
		}
	}
	return ""
}

func runCmd(name string, args ...string) {
	cmd := exec.Command(name, args...)
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	_ = cmd.Run()
}
