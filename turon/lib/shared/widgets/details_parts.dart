import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models/work_status.dart';

/// Sheet header: status stripe, small kind label, big code, status chip,
/// close button (DESIGN §3).
class DetailsHeader extends StatelessWidget {
  final String kind;
  final String code;
  final WorkStatus status;
  final IconData icon;
  final VoidCallback onClose;

  const DetailsHeader({
    super.key,
    required this.kind,
    required this.code,
    required this.status,
    required this.icon,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forStatus(status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 4,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.15)],
            ),
          ),
        ),
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kind,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                  Text(
                    code,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 26,
                      height: 1.1,
                      letterSpacing: -0.6,
                    ),
                  ),
                ],
              ),
            ),
            StatusPill(status: status),
            const SizedBox(width: 4),
            IconButton(
              onPressed: onClose,
              tooltip: 'Yopish',
              style: IconButton.styleFrom(backgroundColor: AppColors.bg),
              icon: const Icon(Icons.close_rounded, size: 20),
            ),
          ],
        ),
      ],
    );
  }
}

class StatusPill extends StatelessWidget {
  final WorkStatus status;

  const StatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(
              color: Color.lerp(color, AppColors.ink, 0.35),
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class MetricData {
  final IconData icon;
  final String label;
  final String value;
  final String? badge;

  const MetricData({
    required this.icon,
    required this.label,
    required this.value,
    this.badge,
  });
}

/// Two-column grid of metric tiles.
class MetricGrid extends StatelessWidget {
  final List<MetricData> metrics;

  const MetricGrid({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final tileWidth = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final m in metrics)
              SizedBox(width: tileWidth, child: _MetricTile(data: m)),
          ],
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  final MetricData data;

  const _MetricTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(AppRadii.button),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(data.icon, size: 16, color: AppColors.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  data.label,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (data.badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    data.badge!,
                    style: const TextStyle(
                      color: AppColors.brand,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            data.value,
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 17,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;

  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.ink,
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      ),
    );
  }
}

/// `[K-1] ──▸ [K-2]` mini diagram used for pipes.
class FlowDiagram extends StatelessWidget {
  final String from;
  final String to;
  final Color color;

  const FlowDiagram({
    super.key,
    required this.from,
    required this.to,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    Widget node(String code) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color, width: 2),
      ),
      child: Text(
        code,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      ),
    );
    return Row(
      children: [
        node(from),
        Expanded(
          child: Row(
            children: [
              Expanded(child: Container(height: 3, color: color)),
              Icon(Icons.play_arrow_rounded, color: color, size: 18),
            ],
          ),
        ),
        node(to),
      ],
    );
  }
}
