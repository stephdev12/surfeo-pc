class ProxyConfig {
  final bool enabled;
  final String? host;
  final int? port;

  const ProxyConfig({
    required this.enabled,
    this.host,
    this.port,
  });

  factory ProxyConfig.fromJson(Map<String, dynamic> json) {
    return ProxyConfig(
      enabled: json['enabled'] as bool? ?? false,
      host: json['host'] as String?,
      port: json['port'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'host': host,
    'port': port,
  };
}

class SshConfig {
  final String host;
  final int port;
  final String username;
  final String password;
  final String payload;
  final bool tls;
  final String? sni;
  final int udpgwPort;
  final ProxyConfig? proxy;

  const SshConfig({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.payload,
    required this.tls,
    this.sni,
    required this.udpgwPort,
    this.proxy,
  });

  factory SshConfig.fromJson(Map<String, dynamic> json) {
    return SshConfig(
      host: json['host'] as String? ?? '',
      port: json['port'] as int? ?? 22,
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      payload: json['payload'] as String? ?? '',
      tls: json['tls'] as bool? ?? false,
      sni: json['sni'] as String?,
      udpgwPort: json['udpgw_port'] as int? ?? 7300,
      proxy: json['proxy'] != null ? ProxyConfig.fromJson(json['proxy']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'host': host,
    'port': port,
    'username': username,
    'password': password,
    'payload': payload,
    'tls': tls,
    'sni': sni,
    'udpgw_port': udpgwPort,
    if (proxy != null) 'proxy': proxy!.toJson(),
  };
}

class TunnelConfig {
  final String type;
  final SshConfig? ssh;
  final int configVersion;

  const TunnelConfig({
    required this.type,
    this.ssh,
    required this.configVersion,
  });

  factory TunnelConfig.fromJson(Map<String, dynamic> json) {
    return TunnelConfig(
      type: json['type'] as String? ?? 'ssh',
      ssh: json['ssh'] != null ? SshConfig.fromJson(json['ssh']) : null,
      configVersion: json['config_version'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    if (ssh != null) 'ssh': ssh!.toJson(),
    'config_version': configVersion,
  };
}
