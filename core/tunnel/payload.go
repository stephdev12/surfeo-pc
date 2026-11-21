package tunnel

import (
	"fmt"
	"strings"
)

// ReplaceMacros replaces all standard injector macros in the custom payload template.
func ReplaceMacros(rawPayload, host string, port int, proxyHost string, proxyPort int, sni string) string {
	if rawPayload == "" {
		return ""
	}

	h := host
	p := fmt.Sprintf("%d", port)
	hp := fmt.Sprintf("%s:%d", host, port)

	if proxyHost != "" {
		h = proxyHost
		if proxyPort > 0 {
			p = fmt.Sprintf("%d", proxyPort)
			hp = fmt.Sprintf("%s:%d", proxyHost, proxyPort)
		}
	}

	effectiveSni := sni
	if effectiveSni == "" {
		effectiveSni = host
	}

	r := strings.NewReplacer(
		"[crlf]", "\r\n",
		"[lf]", "\n",
		"[cr]", "\r",
		"[host_port]", hp,
		"[host]", h,
		"[port]", p,
		"[sni]", effectiveSni,
		"[protocol]", "HTTP/1.1",
		"[ua]", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
		"[method]", "CONNECT",
		"[raw]", fmt.Sprintf("CONNECT %s HTTP/1.1\r\nHost: %s\r\n\r\n", hp, hp),
	)

	return r.Replace(rawPayload)
}
