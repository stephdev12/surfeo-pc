import 'package:flutter/material.dart';
import '../../theme/surfeo_theme.dart';
import '../../models/session_stats.dart';

class ConnectButton extends StatefulWidget {
  final SessionStats stats;
  final VoidCallback onPressed;

  const ConnectButton({
    super.key,
    required this.stats,
    required this.onPressed,
  });

  @override
  State<ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<ConnectButton> with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.stats.state;
    final isConnected = state == 'CONNECTED';
    final isConnecting = state == 'CONNECTING';

    Color glowColor = SurfeoTheme.primaryVariant.withOpacity(0.3);
    Color buttonColor = SurfeoTheme.surfaceElevated;
    Color iconColor = SurfeoTheme.textSecondary;
    String statusText = 'DÉCONNECTÉ';

    if (isConnected) {
      glowColor = SurfeoTheme.primary.withOpacity(0.5);
      buttonColor = SurfeoTheme.primary.withOpacity(0.15);
      iconColor = SurfeoTheme.primary;
      statusText = 'CONNECTÉ';
    } else if (isConnecting) {
      glowColor = SurfeoTheme.warning.withOpacity(0.4);
      buttonColor = SurfeoTheme.warning.withOpacity(0.1);
      iconColor = SurfeoTheme.warning;
      statusText = 'CONNEXION EN COURS...';
    }

    return Column(
      children: [
        GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              final scale = isConnecting ? (1.0 + _animController.value * 0.05) : 1.0;
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: buttonColor,
                    border: Border.all(
                      color: isConnected ? SurfeoTheme.primary : (isConnecting ? SurfeoTheme.warning : SurfeoTheme.border),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: glowColor,
                        blurRadius: isConnected ? 30 : (isConnecting ? 20 : 10),
                        spreadRadius: isConnected ? 5 : 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.power_settings_new_rounded,
                      size: 64,
                      color: iconColor,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Text(
          statusText,
          style: TextStyle(
            color: isConnected ? SurfeoTheme.primary : (isConnecting ? SurfeoTheme.warning : SurfeoTheme.textMuted),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
