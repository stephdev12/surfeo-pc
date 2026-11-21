import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../models/subscription.dart';
import '../models/tunnel_config.dart';

class ApiResult<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  const ApiResult.success(this.data) : error = null, isSuccess = true;
  const ApiResult.failure(this.error) : data = null, isSuccess = false;
}

class SurfeoApiClient {
  static const String defaultBaseUrl = 'https://panel.senstudio.space:2045';
  late final http.Client _client;

  SurfeoApiClient() {
    // Allow self-signed or custom SSL certs for direct VPS/Panel connection
    final ioClient = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true
      ..connectionTimeout = const Duration(seconds: 12);
    _client = IOClient(ioClient);
  }

  Future<ApiResult<Map<String, dynamic>>> activate({
    required String key,
    required String deviceId,
    String? baseUrl,
  }) async {
    final base = baseUrl ?? defaultBaseUrl;
    final url = Uri.parse('$base/api/app/v1/activate');

    try {
      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Device-ID': deviceId,
          'User-Agent': 'Surfeo-PC/1.0.0',
        },
        body: jsonEncode({
          'key': key,
          'device_id': deviceId,
          'platform': 'windows',
        }),
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final sub = Subscription.fromJson(body['subscription'] as Map<String, dynamic>);
        final cfg = TunnelConfig.fromJson(body['config'] as Map<String, dynamic>);
        return ApiResult.success({
          'subscription': sub,
          'config': cfg,
          'config_version': body['config_version'] as int? ?? 1,
        });
      } else {
        return ApiResult.failure(body['message'] as String? ?? 'Code d\'erreur: ${response.statusCode}');
      }
    } catch (e) {
      return ApiResult.failure('Erreur de connexion au serveur Surfeo: $e');
    }
  }

  Future<ApiResult<Subscription>> getStatus(String deviceId, {String? baseUrl}) async {
    final base = baseUrl ?? defaultBaseUrl;
    final url = Uri.parse('$base/api/app/v1/status');

    try {
      final response = await _client.get(
        url,
        headers: {
          'X-Device-ID': deviceId,
          'User-Agent': 'Surfeo-PC/1.0.0',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResult.success(Subscription.fromJson(body));
      }
      return ApiResult.failure('Échec statut: HTTP ${response.statusCode}');
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }
}
