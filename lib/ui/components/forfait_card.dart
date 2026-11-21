import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/surfeo_theme.dart';
import '../../models/subscription.dart';
import '../../models/session_stats.dart';

class ForfaitCard extends StatelessWidget {
  final Subscription? subscription;
  final int cumulativeBytes;
  final VoidCallback onActivatePressed;
  final VoidCallback? onRefreshPressed;
  final bool isRefreshing;

  const ForfaitCard({
    super.key,
    required this.subscription,
    required this.cumulativeBytes,
    required this.onActivatePressed,
    this.onRefreshPressed,
    this.isRefreshing = false,
  });

  @override
  Widget build(BuildContext context) {
    if (subscription == null) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: SurfeoTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SurfeoTheme.border),
        ),
        child: Column(
          children: [
            const Icon(Icons.vpn_key_outlined, size: 44, color: SurfeoTheme.primary),
            const SizedBox(height: 12),
            const Text(
              'Aucun forfait actif',
              style: TextStyle(
                color: SurfeoTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Activez votre clé Surfeo pour commencer à naviguer en toute sécurité.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: SurfeoTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onActivatePressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: SurfeoTheme.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Activer une clé', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    final sub = subscription!;
    final totalUsed = sub.usedBytes + cumulativeBytes;
    final isUnlimited = sub.isUnlimited;
    final quota = sub.quotaBytes;
    final remaining = isUnlimited ? -1 : (quota - totalUsed).clamp(0, quota);
    final progress = (!isUnlimited && quota > 0) ? (totalUsed / quota).clamp(0.0, 1.0) : 0.0;

    String dateStr = 'Illimité';
    if (sub.expiresAt != null) {
      dateStr = DateFormat('dd MMM yyyy à HH:mm').format(sub.expiresAt!);
    } else if (sub.expiresAtStr != null && sub.expiresAtStr!.isNotEmpty) {
      dateStr = sub.expiresAtStr!;
    }

    String statusText = 'ACTIF';
    Color statusColor = SurfeoTheme.success;
    if (sub.isExpired) {
      statusText = 'EXPIRÉ';
      statusColor = SurfeoTheme.error;
    } else if (sub.isQuotaExhausted) {
      statusText = 'QUOTA ÉPUISÉ';
      statusColor = SurfeoTheme.error;
    } else if (!sub.isValid) {
      statusText = 'INACTIF';
      statusColor = SurfeoTheme.warning;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SurfeoTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: sub.isValid ? SurfeoTheme.border : statusColor.withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.shield_outlined, size: 20, color: statusColor),
                  const SizedBox(width: 8),
                  const Text(
                    'Forfait Surfeo',
                    style: TextStyle(
                      color: SurfeoTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (onRefreshPressed != null) ...[
                    IconButton(
                      icon: isRefreshing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: SurfeoTheme.primary),
                            )
                          : const Icon(Icons.refresh, size: 18, color: SurfeoTheme.textMuted),
                      tooltip: 'Actualiser le forfait',
                      onPressed: isRefreshing ? null : onRefreshPressed,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor, width: 1),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: isUnlimited
                ? Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          SurfeoTheme.primary.withOpacity(0.4),
                          SurfeoTheme.primary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  )
                : LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: SurfeoTheme.surfaceElevated,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress > 0.9 ? SurfeoTheme.error : SurfeoTheme.primary,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CONSOMMÉ',
                    style: TextStyle(color: SurfeoTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    SessionStats.formatBytes(totalUsed),
                    style: const TextStyle(color: SurfeoTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'RESTANT / QUOTA',
                    style: TextStyle(color: SurfeoTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isUnlimited ? 'Illimité' : SessionStats.formatBytes(remaining),
                    style: TextStyle(
                      color: isUnlimited ? SurfeoTheme.primary : SurfeoTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(color: SurfeoTheme.border, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.event_outlined, size: 14, color: SurfeoTheme.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    'Expire le : $dateStr',
                    style: const TextStyle(color: SurfeoTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: onActivatePressed,
                style: TextButton.styleFrom(
                  foregroundColor: SurfeoTheme.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.vpn_key_rounded, size: 13),
                label: const Text(
                  'Renouveler',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
