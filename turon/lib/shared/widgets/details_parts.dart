import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models/work_status.dart';

/// Sheet header: status stripe, small kind label, big code, status chip,
/// close button (DESIGN §3). With [onStatusChange] (admins) the status chip
/// opens an inline picker; switching to "Tugallangan" plays a ✓ burst.
class DetailsHeader extends StatefulWidget {
  final String kind;
  final String code;
  final WorkStatus status;
  final IconData icon;
  final VoidCallback onClose;
  final Future<void> Function(WorkStatus status)? onStatusChange;

  const DetailsHeader({
    super.key,
    required this.kind,
    required this.code,
    required this.status,
    required this.icon,
    required this.onClose,
    this.onStatusChange,
  });

  @override
  State<DetailsHeader> createState() => _DetailsHeaderState();
}

class _DetailsHeaderState extends State<DetailsHeader>
    with SingleTickerProviderStateMixin {
  bool _picking = false;
  WorkStatus? _saving;
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  Future<void> _change(WorkStatus next) async {
    final onChange = widget.onStatusChange;
    if (onChange == null || next == widget.status || _saving != null) {
      setState(() => _picking = false);
      return;
    }
    setState(() => _saving = next);
    try {
      await onChange(next);
      if (!mounted) return;
      setState(() => _picking = false);
      if (next == WorkStatus.completed &&
          !MediaQuery.disableAnimationsOf(context)) {
        _burst.forward(from: 0);
      }
    } catch (_) {
      // The caller already showed the error; keep the picker open.
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forStatus(widget.status);
    final canChange = widget.onStatusChange != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
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
            SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(widget.icon, color: color),
                  ),
                  Positioned.fill(child: _CompletionBurst(animation: _burst)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.kind,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                  Text(
                    widget.code,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                      // Codes (K-12) are short; section names can be long.
                      fontSize: widget.code.length > 10 ? 20 : 26,
                      height: 1.1,
                      letterSpacing: -0.6,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: canChange
                  ? () => setState(() => _picking = !_picking)
                  : null,
              child: StatusPill(
                status: widget.status,
                trailing: canChange
                    ? AnimatedRotation(
                        turns: _picking ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.expand_more_rounded,
                          size: 16,
                          color: AppColors.muted,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: widget.onClose,
              tooltip: 'Yopish',
              style: IconButton.styleFrom(backgroundColor: AppColors.bg),
              icon: const Icon(Icons.close_rounded, size: 20),
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: !_picking
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      for (final s in WorkStatus.values) ...[
                        Expanded(
                          child: _StatusOption(
                            status: s,
                            selected: s == widget.status,
                            saving: _saving == s,
                            onTap: () => _change(s),
                          ),
                        ),
                        if (s != WorkStatus.values.last)
                          const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _StatusOption extends StatelessWidget {
  final WorkStatus status;
  final bool selected;
  final bool saving;
  final VoidCallback onTap;

  const _StatusOption({
    required this.status,
    required this.selected,
    required this.saving,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forStatus(status);
    return Material(
      color: selected ? color.withValues(alpha: 0.14) : AppColors.bg,
      borderRadius: BorderRadius.circular(AppRadii.button),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.button),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.button),
            border: Border.all(
              color: selected ? color : AppColors.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              saving
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: color,
                      ),
                    )
                  : Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
              const SizedBox(height: 6),
              Text(
                status.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Expanding green ring + popping check, drawn over the header icon.
class _CompletionBurst extends StatelessWidget {
  final Animation<double> animation;

  const _CompletionBurst({required this.animation});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value;
          if (t == 0 || t == 1) return const SizedBox.shrink();
          final ring = Curves.easeOutCubic.transform(t);
          final pop = Curves.elasticOut.transform((t * 1.4).clamp(0.0, 1.0));
          final fade = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3);
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: 1 + ring * 1.6,
                child: Opacity(
                  opacity: (1 - ring) * 0.8,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.completed,
                        width: 3,
                      ),
                    ),
                  ),
                ),
              ),
              Opacity(
                opacity: fade.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: pop,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.completed,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  final WorkStatus status;
  final Widget? trailing;

  const StatusPill({super.key, required this.status, this.trailing});

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
          if (trailing != null) ...[const SizedBox(width: 2), trailing!],
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
