import 'package:flutter/material.dart';
import '../../theme/surfeo_theme.dart';
import '../../models/session_stats.dart';

class TrafficStatsCard extends StatelessWidget {
  final SessionStats stats;

  const TrafficStatsCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: SurfeoTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SurfeoTheme.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricItem(
                icon: Icons.timer_outlined,
                label: 'DURÉE',
                value: stats.formattedDuration,
                color: SurfeoTheme.textPrimary,
              ),
              _buildMetricItem(
                icon: Icons.arrow_downward_rounded,
                label: 'TÉLÉCHARGEMENT',
                value: SessionStats.formatBytes(stats.rxBytes),
                subValue: SessionStats.formatSpeed(stats.rxRateBps),
                color: SurfeoTheme.primary,
              ),
              _buildMetricItem(
                icon: Icons.arrow_upward_rounded,
                label: 'TÉLÉVERSEMENT',
                value: SessionStats.formatBytes(stats.txBytes),
                subValue: SessionStats.formatSpeed(stats.txRateBps),
                color: SurfeoTheme.primaryVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required String label,
    required String value,
    String? subValue,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: SurfeoTheme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (subValue != null)
          Text(
            subValue,
            style: const TextStyle(
              color: SurfeoTheme.textSecondary,
              fontSize: 11,
            ),
          ),
      ],
    );
  }
}
