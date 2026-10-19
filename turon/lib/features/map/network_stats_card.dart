import 'package:flutter/material.dart';

import '../../core/geo_utils.dart';
import '../../core/theme.dart';
import '../../data/models/manhole.dart';
import '../../data/models/pipe.dart';
import '../../data/models/work_status.dart';

/// Per-status totals of the network (DESIGN §3, mini stats card).
class NetworkStats {
  final Map<WorkStatus, double> meters;
  final Map<WorkStatus, int> pipes;
  final Map<WorkStatus, int> manholes;

  const NetworkStats({
    required this.meters,
    required this.pipes,
    required this.manholes,
  });

  double get totalMeters => meters.values.fold(0.0, (a, b) => a + b);

  factory NetworkStats.from(
    Iterable<Manhole> manholes,
    Iterable<Pipe> pipes,
  ) {
    final meters = {for (final s in WorkStatus.values) s: 0.0};
    final pipeCounts = {for (final s in WorkStatus.values) s: 0};
    final manholeCounts = {for (final s in WorkStatus.values) s: 0};
    for (final p in pipes) {
      meters[p.status] = meters[p.status]! + p.lengthM;
      pipeCounts[p.status] = pipeCounts[p.status]! + 1;
    }
    for (final m in manholes) {
      manholeCounts[m.status] = manholeCounts[m.status]! + 1;
    }
    return NetworkStats(
      meters: meters,
      pipes: pipeCounts,
      manholes: manholeCounts,
    );
  }
}

class NetworkStatsCard extends StatefulWidget {
  final NetworkStats stats;

  const NetworkStatsCard({super.key, required this.stats});

  @override
  State<NetworkStatsCard> createState() => _NetworkStatsCardState();
}

class _NetworkStatsCardState extends State<NetworkStatsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    final total = stats.totalMeters;

    return Material(
      color: AppColors.surface.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(AppRadii.card),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.card),
            boxShadow: AppShadows.floating,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Tarmoq',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _CountUpLength(
                        meters: total,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const Spacer(),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 260),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _StatusBar(stats: stats),
                  if (_expanded) ...[
                    const SizedBox(height: 10),
                    for (final status in WorkStatus.values)
                      _StatusRow(
                        status: status,
                        meters: stats.meters[status]!,
                        pipes: stats.pipes[status]!,
                        manholes: stats.manholes[status]!,
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Three-colour proportional bar; segments animate their width.
class _StatusBar extends StatelessWidget {
  final NetworkStats stats;

  const _StatusBar({required this.stats});

  @override
  Widget build(BuildContext context) {
    final total = stats.totalMeters;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 8,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (total <= 0) {
              return Container(color: AppColors.line);
            }
            return Row(
              children: [
                for (final status in [
                  WorkStatus.completed,
                  WorkStatus.inProgress,
                  WorkStatus.planned,
                ])
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    width:
                        constraints.maxWidth * (stats.meters[status]! / total),
                    color: AppColors.forStatus(status),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final WorkStatus status;
  final double meters;
  final int pipes;
  final int manholes;

  const _StatusRow({
    required this.status,
    required this.meters,
    required this.pipes,
    required this.manholes,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.forStatus(status),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              status.label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '$pipes quvur · $manholes kolodets',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            child: _CountUpLength(
              meters: meters,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animates from the previous value to the new one when [meters] changes.
class _CountUpLength extends StatelessWidget {
  final double meters;
  final TextStyle style;
  final TextAlign? textAlign;

  const _CountUpLength({
    required this.meters,
    required this.style,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: meters),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => Text(
        GeoUtils.formatLength(value),
        style: style,
        textAlign: textAlign,
        maxLines: 1,
      ),
    );
  }
}
