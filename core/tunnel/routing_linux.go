//go:build !windows

package tunnel

import (
	"fmt"
	"net"
	"os/exec"
)

type LinuxTunDevice struct {
	vpsIp string
	gwIp  string
}

func SetupTunDevice(vpsHost string, logger func(string, string)) (*LinuxTunDevice, error) {
	ips, err := net.LookupIP(vpsHost)
	if err != nil || len(ips) == 0 {
		return nil, fmt.Errorf("impossible de résoudre l'adresse IP du serveur VPS: %v", err)
	}
	vpsIp := ips[0].String()

	logger("NET", fmt.Sprintf("Configuration de l'interface TUN Linux pour %s...", vpsIp))

	_ = exec.Command("ip", "tuntap", "add", "dev", "surfeo0", "mode", "tun").Run()
	_ = exec.Command("ip", "addr", "add", "26.26.26.1/24", "dev", "surfeo0").Run()
	_ = exec.Command("ip", "link", "set", "dev", "surfeo0", "mtu", "1400", "up").Run()

	// Bypass route to VPS IP
	_ = exec.Command("ip", "route", "add", vpsIp, "via", "default").Run()

	// Redirect Internet
	_ = exec.Command("ip", "route", "add", "0.0.0.0/1", "dev", "surfeo0").Run()
	_ = exec.Command("ip", "route", "add", "128.0.0.0/1", "dev", "surfeo0").Run()

	return &LinuxTunDevice{
		vpsIp: vpsIp,
	}, nil
}

func (l *LinuxTunDevice) Close() {
	_ = exec.Command("ip", "route", "del", "0.0.0.0/1", "dev", "surfeo0").Run()
	_ = exec.Command("ip", "route", "del", "128.0.0.0/1", "dev", "surfeo0").Run()
	if l.vpsIp != "" {
		_ = exec.Command("ip", "route", "del", l.vpsIp).Run()
	}
	_ = exec.Command("ip", "link", "set", "dev", "surfeo0", "down").Run()
	_ = exec.Command("ip", "tuntap", "del", "dev", "surfeo0", "mode", "tun").Run()
}
