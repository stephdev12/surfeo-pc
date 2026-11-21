import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/session_stats.dart';
import '../models/tunnel_config.dart';

class CoreController {
  final String daemonUrl;
  final http.Client _client = http.Client();

  CoreController({this.daemonUrl = 'http://127.0.0.1:20888'});

  Future<SessionStats> getStatus() async {
    try {
      final res = await _client.get(Uri.parse('$daemonUrl/api/status')).timeout(const Duration(milliseconds: 1500));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        return SessionStats.fromJson(json);
      }
    } catch (_) {}
    return const SessionStats(state: 'DISCONNECTED');
  }

  Future<bool> connect(TunnelConfig config) async {
    try {
      final res = await _client.post(
        Uri.parse('$daemonUrl/api/connect'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(config.toJson()),
      ).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> disconnect() async {
    try {
      final res = await _client.post(Uri.parse('$daemonUrl/api/disconnect')).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> getLogs() async {
    try {
      final res = await _client.get(Uri.parse('$daemonUrl/api/logs')).timeout(const Duration(milliseconds: 1500));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        return list.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return [];
  }
}
