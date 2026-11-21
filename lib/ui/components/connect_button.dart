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
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
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
    final isError = state == 'ERROR';

    Color glowColor = SurfeoTheme.primary.withOpacity(0.25);
    Color buttonColor = SurfeoTheme.surfaceElevated;
    Color iconColor = SurfeoTheme.primary;
    Color borderColor = SurfeoTheme.primary.withOpacity(_isHovered ? 0.8 : 0.45);
    String statusText = 'PRÊT À CONNECTER';
    String subText = 'Cliquez pour établir le tunnel sécurisé';

    if (isConnected) {
      glowColor = const Color(0xFF10B981).withOpacity(0.5);
      buttonColor = const Color(0xFF10B981).withOpacity(0.15);
      iconColor = const Color(0xFF10B981);
      borderColor = const Color(0xFF10B981);
      statusText = 'SÉCURISÉ & CONNECTÉ';
      subText = 'Trafic réseau chiffré via Surfeo';
    } else if (isConnecting) {
      glowColor = SurfeoTheme.warning.withOpacity(0.45);
      buttonColor = SurfeoTheme.warning.withOpacity(0.12);
      iconColor = SurfeoTheme.warning;
      borderColor = SurfeoTheme.warning;
      statusText = 'CONNEXION EN COURS...';
      subText = 'Négociation du protocole sécurisé';
    } else if (isError) {
      glowColor = SurfeoTheme.error.withOpacity(0.4);
      buttonColor = SurfeoTheme.error.withOpacity(0.12);
      iconColor = SurfeoTheme.error;
      borderColor = SurfeoTheme.error;
      statusText = 'ERREUR DE CONNEXION';
      subText = widget.stats.errorMessage ?? 'Cliquez pour réessayer';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            onTap: widget.onPressed,
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                final pulseScale = (isConnecting || isConnected)
                    ? (1.0 + _animController.value * 0.04)
                    : (_isHovered ? 1.04 : 1.0);
                return Transform.scale(
                  scale: pulseScale,
                  child: Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: buttonColor,
                      border: Border.all(
                        color: borderColor,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: glowColor,
                          blurRadius: isConnected ? 32 : (isConnecting ? 24 : (_isHovered ? 24 : 14)),
                          spreadRadius: isConnected ? 6 : (isConnecting ? 3 : (_isHovered ? 3 : 1)),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.power_settings_new_rounded,
                        size: 72,
                        color: iconColor,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          statusText,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isConnected
                ? const Color(0xFF10B981)
                : (isConnecting
                    ? SurfeoTheme.warning
                    : (isError ? SurfeoTheme.error : SurfeoTheme.primary)),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: SurfeoTheme.textMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
