package tunnel

type ProxyConfig struct {
	Enabled bool   `json:"enabled"`
	Host    string `json:"host"`
	Port    int    `json:"port"`
}

type SshConfig struct {
	Host       string       `json:"host"`
	Port       int          `json:"port"`
	Username   string       `json:"username"`
	Password   string       `json:"password"`
	Payload    string       `json:"payload"`
	TLS        bool         `json:"tls"`
	SNI        string       `json:"sni"`
	UdpgwPort  int          `json:"udpgw_port"`
	Proxy      *ProxyConfig `json:"proxy,omitempty"`
}

type TunnelConfig struct {
	Type          string     `json:"type"`
	SSH           *SshConfig `json:"ssh,omitempty"`
	ConfigVersion int        `json:"config_version"`
}

type TunnelStats struct {
	State           string `json:"state"` // DISCONNECTED, CONNECTING, CONNECTED, ERROR
	DurationSeconds int64  `json:"duration_seconds"`
	TxBytes         int64  `json:"tx_bytes"`
	RxBytes         int64  `json:"rx_bytes"`
	TxRateBps       int64  `json:"tx_rate_bps"`
	RxRateBps       int64  `json:"rx_rate_bps"`
	ErrorMessage    string `json:"error_message,omitempty"`
}
