import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 5 separate Telegram-like PIN boxes with active highlight, filled dot, and shake animation.
class PinBoxes extends StatefulWidget {
  final String pin;
  final int length;
  final bool hasError;
  final bool isActive;
  final int shakeTrigger;

  const PinBoxes({
    super.key,
    required this.pin,
    this.length = 5,
    this.hasError = false,
    this.isActive = true,
    this.shakeTrigger = 0,
  });

  @override
  State<PinBoxes> createState() => _PinBoxesState();
}

class _PinBoxesState extends State<PinBoxes>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void didUpdateWidget(covariant PinBoxes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shakeTrigger != oldWidget.shakeTrigger) {
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final t = _shakeController.value;
        final dx = math.sin(t * math.pi * 4) * 10.0 * (1.0 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.length, (i) {
          final isFilled = i < widget.pin.length;
          final isBoxActive = widget.isActive && i == widget.pin.length;
          return Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 10),
            child: PinBox(
              key: ValueKey('pin_box_$i'),
              index: i,
              isFilled: isFilled,
              isActive: isBoxActive,
              hasError: widget.hasError,
            ),
          );
        }),
      ),
    );
  }
}

/// Individual PIN box used inside [PinBoxes].
class PinBox extends StatelessWidget {
  final int index;
  final bool isFilled;
  final bool isActive;
  final bool hasError;

  const PinBox({
    super.key,
    required this.index,
    required this.isFilled,
    required this.isActive,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final Color borderColor;
    final double borderWidth;
    if (hasError) {
      borderColor = colorScheme.error;
      borderWidth = 2.0;
    } else if (isActive) {
      borderColor = colorScheme.primary;
      borderWidth = 2.2;
    } else if (isFilled) {
      borderColor = colorScheme.primary.withValues(alpha: 0.6);
      borderWidth = 1.6;
    } else {
      borderColor = colorScheme.outlineVariant;
      borderWidth = 1.2;
    }

    final Color bgColor = isActive
        ? colorScheme.primaryContainer.withValues(alpha: 0.25)
        : colorScheme.surfaceContainerLowest;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 48,
      height: 54,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      alignment: Alignment.center,
      child: isFilled
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.3, end: 1.0),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Text(
                '●',
                key: ValueKey('pin_dot_$index'),
                style: TextStyle(
                  fontSize: 18,
                  height: 1.0,
                  color: hasError ? colorScheme.error : colorScheme.onSurface,
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

/// Custom 3x4 numeric keypad (1-9, empty, 0, backspace with long-press clear-all).
/// Never invokes the system keyboard.
class NumericKeypad extends StatelessWidget {
  final ValueChanged<String> onDigitPressed;
  final VoidCallback onBackspace;
  final VoidCallback? onClearAll;
  final bool enabled;

  const NumericKeypad({
    super.key,
    required this.onDigitPressed,
    required this.onBackspace,
    this.onClearAll,
    this.enabled = true,
  });

  Widget _buildDigitKey(BuildContext context, String digit) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: SizedBox(
          height: 52,
          child: _PressScale(
            child: Material(
              color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: ValueKey('keypad_$digit'),
                borderRadius: BorderRadius.circular(14),
                onTap: enabled
                    ? () {
                        HapticFeedback.lightImpact();
                        onDigitPressed(digit);
                      }
                    : null,
                child: Center(
                  child: Text(
                    digit,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: enabled
                          ? colorScheme.onSurface
                          : colorScheme.onSurface.withValues(alpha: 0.38),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceKey(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: SizedBox(
          height: 52,
          child: _PressScale(
            child: Material(
              color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const ValueKey('keypad_backspace'),
                borderRadius: BorderRadius.circular(14),
                onTap: enabled
                    ? () {
                        HapticFeedback.lightImpact();
                        onBackspace();
                      }
                    : null,
                onLongPress: enabled
                    ? () {
                        HapticFeedback.mediumImpact();
                        if (onClearAll != null) {
                          onClearAll!();
                        } else {
                          onBackspace();
                        }
                      }
                    : null,
                child: Center(
                  child: Icon(
                    Icons.backspace_outlined,
                    size: 22,
                    color: enabled
                        ? colorScheme.onSurface
                        : colorScheme.onSurface.withValues(alpha: 0.38),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _buildDigitKey(context, '1'),
            _buildDigitKey(context, '2'),
            _buildDigitKey(context, '3'),
          ],
        ),
        Row(
          children: [
            _buildDigitKey(context, '4'),
            _buildDigitKey(context, '5'),
            _buildDigitKey(context, '6'),
          ],
        ),
        Row(
          children: [
            _buildDigitKey(context, '7'),
            _buildDigitKey(context, '8'),
            _buildDigitKey(context, '9'),
          ],
        ),
        Row(
          children: [
            const Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                child: SizedBox(height: 52),
              ),
            ),
            _buildDigitKey(context, '0'),
            _buildBackspaceKey(context),
          ],
        ),
      ],
    );
  }
}

/// Slightly shrinks its child while pressed.
class _PressScale extends StatefulWidget {
  final Widget child;

  const _PressScale({required this.child});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
