import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// White circular floating button used over the map.
class MapRoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final Widget? child;
  final int? badge;

  const MapRoundButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.child,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final button = Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Ink(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: AppShadows.floating,
            ),
            child: Center(
              child: child ?? Icon(icon, color: AppColors.ink, size: 22),
            ),
          ),
        ),
      ),
    );
    if (badge == null) return button;
    return Badge(
      label: Text('$badge'),
      backgroundColor: AppColors.brand,
      child: button,
    );
  }
}

class SpeedDialAction {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const SpeedDialAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
}

/// "+" FAB that fans out labelled actions with a staggered animation;
/// the "+" rotates into "×" (DESIGN §3).
class SpeedDial extends StatefulWidget {
  final List<SpeedDialAction> actions;

  const SpeedDial({super.key, required this.actions});

  @override
  State<SpeedDial> createState() => _SpeedDialState();
}

class _SpeedDialState extends State<SpeedDial>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  bool get _open => _controller.status == AnimationStatus.forward ||
      _controller.status == AnimationStatus.completed;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    _open ? _controller.reverse() : _controller.forward();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.actions.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < count; i++)
          _buildAction(widget.actions[i], (count - 1 - i) / count),
        FloatingActionButton(
          heroTag: 'speed_dial_fab',
          tooltip: _open ? 'Yopish' : 'Qo\'shish',
          onPressed: _toggle,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Transform.rotate(
              angle: Curves.easeOutBack.transform(_controller.value) *
                  0.785398, // 45°
              child: child,
            ),
            child: const Icon(Icons.add_rounded, size: 30),
          ),
        ),
      ],
    );
  }

  Widget _buildAction(SpeedDialAction action, double delay) {
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Interval(delay * 0.5, 0.5 + delay * 0.5, curve: Curves.easeOutBack),
      reverseCurve: Curves.easeIn,
    );
    return AnimatedBuilder(
      animation: curve,
      builder: (context, child) {
        final v = curve.value.clamp(0.0, 1.2);
        if (_controller.value == 0) return const SizedBox.shrink();
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - v)),
            child: Transform.scale(
              scale: 0.8 + 0.2 * v,
              alignment: Alignment.centerRight,
              child: child,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12, right: 4),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.button),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.button),
            onTap: () {
              _controller.reverse();
              setState(() {});
              action.onPressed();
            },
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.button),
                boxShadow: AppShadows.floating,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(action.icon, color: AppColors.brand, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    action.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
