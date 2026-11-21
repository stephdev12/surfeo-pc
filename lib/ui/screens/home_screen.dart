import 'dart:async';
import 'dart:io';
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
import '../components/reactivation_card.dart';
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
  bool _showReactivationCard = false;
  bool _isRefreshing = false;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _subscription = widget.storage.getSubscription();
    _tunnelConfig = widget.storage.getTunnelConfig();

    if (_subscription == null || !_subscription!.isValid) {
      _showReactivationCard = true;
    }

    _ensureDaemonRunning();
    _startPolling();

    // Auto-refresh subscription from panel on startup if key exists
    if (_subscription != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshStatus(silent: true);
      });
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _ensureDaemonRunning() async {
    try {
      final s = await widget.coreController.getStatus();
      if (s.state != 'DISCONNECTED' && s.state != 'CONNECTED') {
        // try to start
      }
    } catch (_) {
      try {
        final exeDir = File(Platform.resolvedExecutable).parent.path;
        final daemonPath = Platform.isWindows
            ? '$exeDir\\surfeo-core.exe'
            : '$exeDir/surfeo-core';
        if (await File(daemonPath).exists()) {
          await Process.start(daemonPath, [], mode: ProcessStartMode.detached);
        }
      } catch (_) {}
    }
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

  Future<void> _refreshStatus({bool silent = false}) async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      final deviceId = widget.storage.getDeviceId();
      final res = await widget.apiClient.getStatus(deviceId);

      if (res.isSuccess && res.data != null) {
        final newSub = res.data!;
        await widget.storage.saveSubscription(newSub);

        if (mounted) {
          setState(() {
            _subscription = newSub;
            if (newSub.isValid) {
              _showReactivationCard = false;
            }
          });

          if (!silent) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: SurfeoTheme.success, size: 20),
                    SizedBox(width: 10),
                    Text('Statut du forfait actualisé avec succès.'),
                  ],
                ),
                backgroundColor: SurfeoTheme.surfaceElevated,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } else if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: SurfeoTheme.warning, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(res.error ?? 'Impossible d\'actualiser le forfait')),
              ],
            ),
            backgroundColor: SurfeoTheme.surfaceElevated,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<String?> _handleActivateKey(String key) async {
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

      if (mounted) {
        setState(() {
          _subscription = sub;
          _tunnelConfig = cfg;
          _showReactivationCard = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.verified_rounded, color: SurfeoTheme.success, size: 20),
                SizedBox(width: 10),
                Text('Abonnement Surfeo activé avec succès !'),
              ],
            ),
            backgroundColor: SurfeoTheme.surfaceElevated,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return null;
    }
    return res.error ?? 'Échec de l\'activation';
  }

  Future<void> _handleConnectToggle() async {
    if (_stats.isConnected || _stats.isConnecting) {
      await widget.coreController.disconnect();
      return;
    }

    if (_tunnelConfig == null) {
      setState(() => _showReactivationCard = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez activer une clé Surfeo pour vous connecter.'),
          backgroundColor: SurfeoTheme.warning,
        ),
      );
      return;
    }

    // If subscription is marked invalid, try to refresh first in case it was updated on panel
    if (_subscription != null && !_subscription!.isValid) {
      await _refreshStatus(silent: true);
    }

    if (_subscription != null && !_subscription!.isValid) {
      setState(() => _showReactivationCard = true);
      String msg = 'Forfait inactif sur le serveur. Veuillez réactiver votre clé.';
      if (_subscription!.isExpired) {
        msg = 'Votre forfait a expiré. Veuillez le renouveler avec une nouvelle clé.';
      } else if (_subscription!.isQuotaExhausted) {
        msg = 'Quota de données épuisé. Veuillez recharger votre forfait.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: SurfeoTheme.error,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final success = await widget.coreController.connect(_tunnelConfig!);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Le moteur réseau Surfeo ne répond pas. Vérifiez que l\'application a été lancée via Lancer_Surfeo.bat avec les droits administrateur.',
          ),
          backgroundColor: SurfeoTheme.error,
          duration: Duration(seconds: 5),
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
            // Top Navigation / Header Bar
            _buildHeader(deviceId, shortDeviceId),
            const Divider(color: SurfeoTheme.border, height: 1),

            // Responsive Body
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 760;
                  if (isWide) {
                    return _buildDesktopLayout();
                  } else {
                    return _buildNarrowLayout();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String deviceId, String shortDeviceId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      color: SurfeoTheme.background,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  SurfeoTheme.primary.withOpacity(0.2),
                  SurfeoTheme.primaryVariant.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: SurfeoTheme.primary.withOpacity(0.3)),
            ),
            child: const Icon(Icons.shield_rounded, color: SurfeoTheme.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'SURFEO',
                    style: TextStyle(
                      color: SurfeoTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: SurfeoTheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'PC PRO',
                      style: TextStyle(
                        color: SurfeoTheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Text(
                'Next-Gen Secure Tunneling System',
                style: TextStyle(
                  color: SurfeoTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Spacer(),

          // Quick Action: Refresh Button
          OutlinedButton.icon(
            onPressed: _isRefreshing ? null : () => _refreshStatus(),
            style: OutlinedButton.styleFrom(
              foregroundColor: SurfeoTheme.textPrimary,
              side: const BorderSide(color: SurfeoTheme.border),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: _isRefreshing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: SurfeoTheme.primary),
                  )
                : const Icon(Icons.refresh_rounded, size: 16, color: SurfeoTheme.primary),
            label: Text(
              _isRefreshing ? 'Actualisation...' : 'Actualiser',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),

          // Quick Action: Reactivate / Key Button
          ElevatedButton.icon(
            onPressed: () => setState(() => _showReactivationCard = !_showReactivationCard),
            style: ElevatedButton.styleFrom(
              backgroundColor: _showReactivationCard
                  ? SurfeoTheme.primary
                  : SurfeoTheme.surfaceElevated,
              foregroundColor: _showReactivationCard ? Colors.black : SurfeoTheme.textPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: _showReactivationCard ? SurfeoTheme.primary : SurfeoTheme.border,
                ),
              ),
            ),
            icon: Icon(
              Icons.vpn_key_rounded,
              size: 16,
              color: _showReactivationCard ? Colors.black : SurfeoTheme.primary,
            ),
            label: Text(
              _showReactivationCard ? 'Fermer la clé' : 'Réactiver clé',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),

          // Device Identifier Badge
          Tooltip(
            message: 'Identifiant unique de votre machine: $deviceId',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: SurfeoTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: SurfeoTheme.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.computer_rounded, size: 14, color: SurfeoTheme.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    'PC: $shortDeviceId',
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
          ),
        ],
      ),
    );
  }

  // Desktop 2-Column Split Layout
  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Main Power / Connection Dashboard
        SizedBox(
          width: 380,
          child: Container(
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: SurfeoTheme.border)),
              color: SurfeoTheme.background,
            ),
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                ConnectButton(
                  stats: _stats,
                  onPressed: _handleConnectToggle,
                ),
                const SizedBox(height: 32),

                // Server Connection Info Card
                _buildServerStatusBadge(),
                const Spacer(),

                // Connection Duration Timer Badge
                if (_stats.isConnected) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: SurfeoTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: SurfeoTheme.success.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined, size: 16, color: SurfeoTheme.success),
                        const SizedBox(width: 8),
                        Text(
                          'Actif depuis ${_stats.formattedDuration}',
                          style: const TextStyle(
                            color: SurfeoTheme.success,
                            fontSize: 13,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Right Column: Forfait, Traffic Stats, Reactivation & Logs
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Reactivation Card (Toggled or when invalid)
                if (_showReactivationCard || _subscription == null || !_subscription!.isValid) ...[
                  ReactivationCard(
                    onActivate: _handleActivateKey,
                    onDismiss: (_subscription != null && _subscription!.isValid)
                        ? () => setState(() => _showReactivationCard = false)
                        : null,
                  ),
                  const SizedBox(height: 20),
                ],

                // Forfait Card
                ForfaitCard(
                  subscription: _subscription,
                  cumulativeBytes: _stats.txBytes + _stats.rxBytes,
                  onActivatePressed: () => setState(() => _showReactivationCard = true),
                  onRefreshPressed: _refreshStatus,
                  isRefreshing: _isRefreshing,
                ),
                const SizedBox(height: 20),

                // Live Traffic Statistics
                TrafficStatsCard(stats: _stats),
                const SizedBox(height: 20),

                // System Logs Collapsible Console
                _buildLogsSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Narrow Screen Layout (Mobile / Small Windows)
  Widget _buildNarrowLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
          ConnectButton(
            stats: _stats,
            onPressed: _handleConnectToggle,
          ),
          const SizedBox(height: 20),

          if (_showReactivationCard || _subscription == null || !_subscription!.isValid) ...[
            ReactivationCard(
              onActivate: _handleActivateKey,
              onDismiss: (_subscription != null && _subscription!.isValid)
                  ? () => setState(() => _showReactivationCard = false)
                  : null,
            ),
            const SizedBox(height: 20),
          ],

          ForfaitCard(
            subscription: _subscription,
            cumulativeBytes: _stats.txBytes + _stats.rxBytes,
            onActivatePressed: () => setState(() => _showReactivationCard = true),
            onRefreshPressed: _refreshStatus,
            isRefreshing: _isRefreshing,
          ),
          const SizedBox(height: 20),

          TrafficStatsCard(stats: _stats),
          const SizedBox(height: 20),

          _buildLogsSection(),
        ],
      ),
    );
  }

  Widget _buildServerStatusBadge() {
    final host = _tunnelConfig?.ssh?.host ?? 'Non configuré';
    final port = _tunnelConfig?.ssh?.port ?? 0;
    final isConnected = _stats.isConnected;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SurfeoTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isConnected ? SurfeoTheme.success.withOpacity(0.3) : SurfeoTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.dns_rounded,
                size: 16,
                color: isConnected ? SurfeoTheme.success : SurfeoTheme.primary,
              ),
              const SizedBox(width: 8),
              const Text(
                'SERVEUR SURFEO',
                style: TextStyle(
                  color: SurfeoTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isConnected
                      ? SurfeoTheme.success
                      : (_stats.isConnecting ? SurfeoTheme.warning : SurfeoTheme.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            host,
            style: const TextStyle(
              color: SurfeoTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            port > 0 ? 'Port: $port • SSH over WSS / Wintun' : 'Aucun tunnel actif',
            style: const TextStyle(
              color: SurfeoTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _showLogs = !_showLogs),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: SurfeoTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: SurfeoTheme.border),
            ),
            child: Row(
              children: [
                Icon(
                  _showLogs ? Icons.terminal_rounded : Icons.terminal_outlined,
                  size: 18,
                  color: _showLogs ? SurfeoTheme.primary : SurfeoTheme.textMuted,
                ),
                const SizedBox(width: 10),
                Text(
                  _showLogs ? 'Masquer la console système' : 'Afficher la console & journal réseau',
                  style: TextStyle(
                    color: _showLogs ? SurfeoTheme.primary : SurfeoTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Icon(
                  _showLogs ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: SurfeoTheme.textMuted,
                ),
              ],
            ),
          ),
        ),
        if (_showLogs) ...[
          const SizedBox(height: 12),
          LogConsole(logs: _logs),
        ],
      ],
    );
  }
}
