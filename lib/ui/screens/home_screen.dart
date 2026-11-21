import 'dart:async';
import 'package:flutter/material.dart';
import '../../api/core_controller.dart';
import '../../api/surfeo_api_client.dart';
import '../../models/session_stats.dart';
import '../../models/subscription.dart';
import '../../models/tunnel_config.dart';
import '../../storage/persistent_storage.dart';
import '../../theme/surfeo_theme.dart';
import '../components/connect_button.dart';
import '../components/forfait_card.dart';
import '../components/traffic_stats_card.dart';
import '../components/log_console.dart';
import '../components/activation_dialog.dart';

class HomeScreen extends StatefulWidget {
  final PersistentStorage storage;
  final SurfeoApiClient apiClient;
  final CoreController coreController;

  const HomeScreen({
    super.key,
    required this.storage,
    required this.apiClient,
    required this.coreController,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Subscription? _subscription;
  TunnelConfig? _tunnelConfig;
  SessionStats _stats = const SessionStats();
  List<String> _logs = [];
  bool _showLogs = false;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _subscription = widget.storage.getSubscription();
    _tunnelConfig = widget.storage.getTunnelConfig();

    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final s = await widget.coreController.getStatus();
      final l = await widget.coreController.getLogs();

      if (mounted) {
        setState(() {
          _stats = s;
          _logs = l;
        });
      }
    });
  }

  Future<void> _handleConnectToggle() async {
    if (_stats.isConnected || _stats.isConnecting) {
      await widget.coreController.disconnect();
    } else {
      if (_tunnelConfig == null) {
        _showActivationDialog();
        return;
      }
      await widget.coreController.connect(_tunnelConfig!);
    }
  }

  Future<void> _showActivationDialog() async {
    final success = await showDialog<bool>(
      context: context,
      builder: (context) => ActivationDialog(
        onActivate: (key) async {
          final deviceId = widget.storage.getDeviceId();
          final res = await widget.apiClient.activate(key: key, deviceId: deviceId);
          if (res.isSuccess && res.data != null) {
            final sub = res.data!['subscription'] as Subscription;
            final cfg = res.data!['config'] as TunnelConfig;
            final version = res.data!['config_version'] as int;

            await widget.storage.saveActivationKey(key);
            await widget.storage.saveSubscription(sub);
            await widget.storage.saveTunnelConfig(cfg);
            await widget.storage.saveConfigVersion(version);

            setState(() {
              _subscription = sub;
              _tunnelConfig = cfg;
            });
            return null; // success
          }
          return res.error ?? 'Échec de l\'activation';
        },
      ),
    );

    if (success == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Abonnement Surfeo activé avec succès !'),
          backgroundColor: SurfeoTheme.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceId = widget.storage.getDeviceId();
    final shortDeviceId = deviceId.length > 8 ? deviceId.substring(0, 8).toUpperCase() : deviceId;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: SurfeoTheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shield_rounded, color: SurfeoTheme.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SURFEO',
                        style: TextStyle(
                          color: SurfeoTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        'PC & Desktop Edition',
                        style: TextStyle(
                          color: SurfeoTheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: SurfeoTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: SurfeoTheme.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.fingerprint, size: 14, color: SurfeoTheme.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          'ID: $shortDeviceId',
                          style: const TextStyle(
                            color: SurfeoTheme.textSecondary,
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: SurfeoTheme.border, height: 1),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 12),

                    // Main Power Button
                    ConnectButton(
                      stats: _stats,
                      onPressed: _handleConnectToggle,
                    ),

                    const SizedBox(height: 28),

                    // Live Session Stats Card
                    TrafficStatsCard(stats: _stats),

                    const SizedBox(height: 16),

                    // Forfait Card
                    ForfaitCard(
                      subscription: _subscription,
                      cumulativeBytes: _stats.txBytes + _stats.rxBytes,
                      onActivatePressed: _showActivationDialog,
                    ),

                    const SizedBox(height: 16),

                    // Console Log Toggle
                    InkWell(
                      onTap: () => setState(() => _showLogs = !_showLogs),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _showLogs ? Icons.terminal : Icons.terminal_outlined,
                              size: 16,
                              color: _showLogs ? SurfeoTheme.primary : SurfeoTheme.textMuted,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _showLogs ? 'Masquer le journal système' : 'Afficher le journal de connexion',
                              style: TextStyle(
                                color: _showLogs ? SurfeoTheme.primary : SurfeoTheme.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (_showLogs) ...[
                      const SizedBox(height: 10),
                      LogConsole(logs: _logs),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
