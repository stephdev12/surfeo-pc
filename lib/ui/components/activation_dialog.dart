import 'package:flutter/material.dart';
import '../../theme/surfeo_theme.dart';

class ActivationDialog extends StatefulWidget {
  final Future<String?> Function(String key) onActivate;

  const ActivationDialog({super.key, required this.onActivate});

  @override
  State<ActivationDialog> createState() => _ActivationDialogState();
}

class _ActivationDialogState extends State<ActivationDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _submit() async {
    final key = _controller.text.trim();
    if (key.isEmpty) {
      setState(() => _errorMessage = 'Veuillez saisir votre clé d\'activation');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final error = await widget.onActivate(key);

    if (mounted) {
      if (error == null) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: SurfeoTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: SurfeoTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.vpn_key_rounded, color: SurfeoTheme.primary, size: 24),
                const SizedBox(width: 10),
                const Text(
                  'Activer mon forfait',
                  style: TextStyle(
                    color: SurfeoTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: SurfeoTheme.textMuted, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Collez ci-dessous la clé d\'activation fournie par votre administrateur Surfeo (format NVX1-SEN-...) :',
              style: TextStyle(color: SurfeoTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              style: const TextStyle(color: SurfeoTheme.textPrimary, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'NVX1-SEN-XXXX-XXXX',
                hintStyle: const TextStyle(color: SurfeoTheme.textMuted),
                filled: true,
                fillColor: SurfeoTheme.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: SurfeoTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: SurfeoTheme.primary),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: const TextStyle(color: SurfeoTheme.error, fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: SurfeoTheme.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Text(
                        'Activer maintenant',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
