import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription.dart';
import '../models/tunnel_config.dart';

class PersistentStorage {
  static const _keyActivationKey = 'activation_key';
  static const _keyDeviceId = 'device_id';
  static const _keySubscription = 'subscription';
  static const _keyTunnelConfig = 'tunnel_config';
  static const _keyConfigVersion = 'config_version';
  static const _keyPersistentBytes = 'persistent_transferred_bytes';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String getDeviceId() {
    String? id = _prefs.getString(_keyDeviceId);
    if (id == null || id.isEmpty) {
      final random = Random();
      final bytes = List<int>.generate(16, (i) => random.nextInt(256));
      id = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      _prefs.setString(_keyDeviceId, id);
    }
    return id;
  }

  String? getActivationKey() => _prefs.getString(_keyActivationKey);
  Future<void> saveActivationKey(String key) => _prefs.setString(_keyActivationKey, key);

  Subscription? getSubscription() {
    final str = _prefs.getString(_keySubscription);
    if (str == null || str.isEmpty) return null;
    try {
      return Subscription.fromJson(jsonDecode(str) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSubscription(Subscription sub) =>
      _prefs.setString(_keySubscription, jsonEncode(sub.toJson()));

  TunnelConfig? getTunnelConfig() {
    final str = _prefs.getString(_keyTunnelConfig);
    if (str == null || str.isEmpty) return null;
    try {
      return TunnelConfig.fromJson(jsonDecode(str) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveTunnelConfig(TunnelConfig cfg) =>
      _prefs.setString(_keyTunnelConfig, jsonEncode(cfg.toJson()));

  int getConfigVersion() => _prefs.getInt(_keyConfigVersion) ?? 0;
  Future<void> saveConfigVersion(int version) => _prefs.setInt(_keyConfigVersion, version);

  int getPersistentTransferredBytes() => _prefs.getInt(_keyPersistentBytes) ?? 0;
  Future<void> savePersistentTransferredBytes(int bytes) =>
      _prefs.setInt(_keyPersistentBytes, bytes);
}
