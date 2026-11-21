class Subscription {
  final String state;
  final int quotaBytes;
  final int usedBytes;
  final int expiresAt;
  final int activeSessions;
  final int serverTime;

  const Subscription({
    required this.state,
    required this.quotaBytes,
    required this.usedBytes,
    required this.expiresAt,
    required this.activeSessions,
    required this.serverTime,
  });

  bool get isExpired => (expiresAt * 1000) < DateTime.now().millisecondsSinceEpoch;
  bool get isQuotaExhausted => quotaBytes > 0 && usedBytes >= quotaBytes;
  bool get isValid => state.toUpperCase() == 'ACTIVE' && !isExpired && !isQuotaExhausted;

  int get remainingBytes => (quotaBytes - usedBytes).clamp(0, quotaBytes);
  double get usagePercent => quotaBytes > 0 ? (usedBytes / quotaBytes).clamp(0.0, 1.0) : 0.0;

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      state: json['state'] as String? ?? 'INACTIVE',
      quotaBytes: json['quota_bytes'] as int? ?? 0,
      usedBytes: json['used_bytes'] as int? ?? 0,
      expiresAt: json['expires_at'] as int? ?? 0,
      activeSessions: json['active_sessions'] as int? ?? 0,
      serverTime: json['server_time'] as int? ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000),
    );
  }

  Map<String, dynamic> toJson() => {
    'state': state,
    'quota_bytes': quotaBytes,
    'used_bytes': usedBytes,
    'expires_at': expiresAt,
    'active_sessions': activeSessions,
    'server_time': serverTime,
  };
}
