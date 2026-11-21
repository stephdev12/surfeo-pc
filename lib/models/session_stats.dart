class SessionStats {
  final String state;
  final int durationSeconds;
  final int txBytes;
  final int rxBytes;
  final int txRateBps;
  final int rxRateBps;
  final String? errorMessage;

  const SessionStats({
    this.state = 'DISCONNECTED',
    this.durationSeconds = 0,
    this.txBytes = 0,
    this.rxBytes = 0,
    this.txRateBps = 0,
    this.rxRateBps = 0,
    this.errorMessage,
  });

  bool get isConnected => state == 'CONNECTED';
  bool get isConnecting => state == 'CONNECTING';
  bool get isDisconnected => state == 'DISCONNECTED';
  bool get isError => state == 'ERROR';

  String get formattedDuration {
    final hours = (durationSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((durationSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (durationSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024.0;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024.0;
    if (mb < 1024) return '${mb.toStringAsFixed(2)} MB';
    final gb = mb / 1024.0;
    return '${gb.toStringAsFixed(2)} GB';
  }

  static String formatSpeed(int bytesPerSec) {
    final bytes = bytesPerSec.clamp(0, 1000000000);
    return '${formatBytes(bytes)}/s';
  }

  factory SessionStats.fromJson(Map<String, dynamic> json) {
    return SessionStats(
      state: json['state'] as String? ?? 'DISCONNECTED',
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      txBytes: json['tx_bytes'] as int? ?? 0,
      rxBytes: json['rx_bytes'] as int? ?? 0,
      txRateBps: json['tx_rate_bps'] as int? ?? 0,
      rxRateBps: json['rx_rate_bps'] as int? ?? 0,
      errorMessage: json['error_message'] as String?,
    );
  }
}
