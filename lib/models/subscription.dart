class Subscription {
  final String state;
  final int quotaBytes; // 0 = illimité
  final int usedBytes;
  final String? expiresAtStr;
  final DateTime? expiresAt;
  final int activeSessions;
  final String? serverTime;

  const Subscription({
    required this.state,
    required this.quotaBytes,
    required this.usedBytes,
    this.expiresAtStr,
    this.expiresAt,
    required this.activeSessions,
    this.serverTime,
  });

  bool get isUnlimited => quotaBytes <= 0;
  bool get isActive => state.toLowerCase() == 'active';
  bool get isExpired {
    if (expiresAt == null) return false;
    return expiresAt!.isBefore(DateTime.now());
  }
  bool get isQuotaExhausted => !isUnlimited && usedBytes >= quotaBytes;
  bool get isValid => isActive && !isExpired && !isQuotaExhausted;

  int get remainingBytes => isUnlimited ? -1 : (quotaBytes - usedBytes).clamp(0, quotaBytes);
  double get usagePercent => (!isUnlimited && quotaBytes > 0) ? (usedBytes / quotaBytes).clamp(0.0, 1.0) : 0.0;

  factory Subscription.fromJson(Map<String, dynamic> json) {
    final rawQuota = json['quotaBytes'] ?? json['quota_bytes'] ?? 0;
    final rawUsed = json['usedBytes'] ?? json['used_bytes'] ?? 0;
    final rawSessions = json['activeSessions'] ?? json['active_sessions'] ?? 0;
    final rawState = json['state'] as String? ?? 'active';

    final rawExp = json['expiresAt'] ?? json['expires_at'];
    DateTime? parsedExpiry;
    String? expStr;
    if (rawExp is String && rawExp.isNotEmpty) {
      expStr = rawExp;
      try {
        parsedExpiry = DateTime.parse(rawExp);
      } catch (_) {}
    } else if (rawExp is int && rawExp > 0) {
      parsedExpiry = DateTime.fromMillisecondsSinceEpoch(rawExp * 1000);
      expStr = parsedExpiry.toIso8601String();
    }

    return Subscription(
      state: rawState,
      quotaBytes: rawQuota is int ? rawQuota : int.tryParse(rawQuota.toString()) ?? 0,
      usedBytes: rawUsed is int ? rawUsed : int.tryParse(rawUsed.toString()) ?? 0,
      expiresAtStr: expStr,
      expiresAt: parsedExpiry,
      activeSessions: rawSessions is int ? rawSessions : int.tryParse(rawSessions.toString()) ?? 0,
      serverTime: json['serverTime']?.toString() ?? json['server_time']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'state': state,
    'quotaBytes': quotaBytes,
    'usedBytes': usedBytes,
    'expiresAt': expiresAtStr,
    'activeSessions': activeSessions,
    'serverTime': serverTime,
  };
}
