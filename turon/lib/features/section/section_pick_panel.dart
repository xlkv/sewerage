import 'package:flutter/material.dart';

import '../../core/geo_utils.dart';
import '../../core/theme.dart';
import 'section_stats.dart';

/// Bottom bar while picking a section's pipes: live figures + Next.
class SectionPickPanel extends StatelessWidget {
  final SectionStats stats;
  final VoidCallback? onUndoAll;
  final VoidCallback? onNext;

  const SectionPickPanel({
    super.key,
    required this.stats,
    required this.onUndoAll,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final diameters = stats.byDiameter.map((d) => 'Ø${d.diameterMm}').join(' ');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: AppShadows.floating,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      formatLength(stats.lengthM),
                      key: ValueKey(stats.lengthM.round()),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${stats.pipeCount} quvur · ${stats.manholeCount} kolodets'
                    '${diameters.isEmpty ? '' : ' · $diameters'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            if (onUndoAll != null)
              IconButton(
                tooltip: 'Tanlovni tozalash',
                onPressed: onUndoAll,
                icon: const Icon(Icons.restart_alt_rounded),
              ),
            const SizedBox(width: 4),
            FilledButton.icon(
              onPressed: onNext,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Davom etish'),
            ),
          ],
        ),
      ),
    );
  }
}
