import 'package:flutter/material.dart';
import '../../theme/surfeo_theme.dart';

class LogConsole extends StatefulWidget {
  final List<String> logs;

  const LogConsole({super.key, required this.logs});

  @override
  State<LogConsole> createState() => _LogConsoleState();
}

class _LogConsoleState extends State<LogConsole> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void didUpdateWidget(covariant LogConsole oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_autoScroll && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF070A12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SurfeoTheme.border),
      ),
      child: widget.logs.isEmpty
          ? const Center(
              child: Text(
                'En attente de connexion...',
                style: TextStyle(color: SurfeoTheme.textMuted, fontSize: 12),
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              itemCount: widget.logs.length,
              itemBuilder: (context, index) {
                final line = widget.logs[index];
                Color color = SurfeoTheme.textSecondary;
                if (line.contains('[SUCCESS]')) {
                  color = SurfeoTheme.success;
                } else if (line.contains('[ERROR]')) {
                  color = SurfeoTheme.error;
                } else if (line.contains('[WARN]')) {
                  color = SurfeoTheme.warning;
                } else if (line.contains('[SSH]') || line.contains('[NET]') || line.contains('[PAYLOAD]')) {
                  color = SurfeoTheme.primary;
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    line,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: color,
                      height: 1.3,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
