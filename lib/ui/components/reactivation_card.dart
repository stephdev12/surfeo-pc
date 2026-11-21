import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/surfeo_theme.dart';

class ReactivationCard extends StatefulWidget {
  final Future<String?> Function(String key) onActivate;
  final VoidCallback? onDismiss;

  const ReactivationCard({
    super.key,
    required this.onActivate,
    this.onDismiss,
  });

  @override
  State<ReactivationCard> createState() => _ReactivationCardState();
}

class _ReactivationCardState extends State<ReactivationCard> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      setState(() {
        _controller.text = data.text!.trim();
      });
    }
  }

  Future<void> _submit() async {
    final key = _controller.text.trim();
    if (key.isEmpty) {
      setState(() => _errorMessage = 'Veuillez saisir votre clé d\'activation.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final error = await widget.onActivate(key);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (error == null) {
          _successMessage = 'Forfait réactivé avec succès !';
          _controller.clear();
        } else {
          _errorMessage = error;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SurfeoTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _errorMessage != null
              ? SurfeoTheme.error.withOpacity(0.5)
              : SurfeoTheme.primary.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: SurfeoTheme.primary.withOpacity(0.05),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: SurfeoTheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.vpn_key_rounded, color: SurfeoTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Réactivation & Renouvellement',
                      style: TextStyle(
                        color: SurfeoTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Saisissez une clé pour prolonger votre accès',
                      style: TextStyle(color: SurfeoTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (widget.onDismiss != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: SurfeoTheme.textMuted),
                  onPressed: widget.onDismiss,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: SurfeoTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'NVX1-SEN-XXXXX-XXXXX...',
                    hintStyle: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: SurfeoTheme.textMuted,
                      letterSpacing: 0.5,
                    ),
                    filled: true,
                    fillColor: SurfeoTheme.surfaceElevated,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: SurfeoTheme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: SurfeoTheme.primary, width: 1.5),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.content_paste_rounded, size: 18, color: SurfeoTheme.primary),
                      tooltip: 'Coller depuis le presse-papier',
                      onPressed: _pasteFromClipboard,
                    ),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: SurfeoTheme.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Text(
                        'Activer',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
              ),
            ],
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: SurfeoTheme.error.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: SurfeoTheme.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: SurfeoTheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: SurfeoTheme.error, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_successMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: SurfeoTheme.success.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: SurfeoTheme.success.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 16, color: SurfeoTheme.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _successMessage!,
                      style: const TextStyle(color: SurfeoTheme.success, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
