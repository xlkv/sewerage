import 'package:flutter/material.dart';

/// Adaptive layout widget (LLD 4.8 & Step 5 #5 / C):
/// - Tablet / wide (`width >= 600`): Map + fixed 380dp right side panel for both details and forms.
/// - Phone (`width < 600`):
///   - Details: Non-modal iOS-style DraggableScrollableSheet: snaps at 45% / 92%,
///     inner list scroll hands off to the sheet, swipe down to dismiss, grabber drag.
///   - Forms (add/edit): Full-height iOS-style sheet (`20dp` top corners, grabber handle).
class AdaptivePanel extends StatefulWidget {
  final Widget mapChild;
  final Widget Function(
    BuildContext context,
    ScrollController? scrollController,
  )?
  detailsBuilder;
  final Object? detailsKey;
  final VoidCallback? onDismissDetails;
  final Widget? formChild;

  const AdaptivePanel({
    super.key,
    required this.mapChild,
    this.detailsBuilder,
    this.detailsKey,
    this.onDismissDetails,
    this.formChild,
  });

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 600;

  static const double detailsInitialSize = 0.45;
  static const double detailsMaxSize = 0.92;
  static const List<double> detailsSnapSizes = [
    detailsInitialSize,
    detailsMaxSize,
  ];
  static const double sheetTopRadius = 20.0;

  @override
  State<AdaptivePanel> createState() => _AdaptivePanelState();
}

class _AdaptivePanelState extends State<AdaptivePanel> {
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  bool _dismissTriggered = false;

  @override
  void didUpdateWidget(covariant AdaptivePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.detailsBuilder != null &&
        (oldWidget.detailsBuilder == null ||
            widget.detailsKey != oldWidget.detailsKey)) {
      _dismissTriggered = false;
    }
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  void _dismissSheet() {
    if (_dismissTriggered) return;
    _dismissTriggered = true;
    widget.onDismissDetails?.call();
  }

  // The grabber sits outside the scrollable, so it drives the sheet directly.
  void _onGrabberDragUpdate(DragUpdateDetails details, double maxHeight) {
    if (!_sheetController.isAttached || maxHeight <= 0) return;
    final next =
        (_sheetController.size - (details.primaryDelta ?? 0) / maxHeight).clamp(
          0.0,
          AdaptivePanel.detailsMaxSize,
        );
    _sheetController.jumpTo(next);
  }

  void _onGrabberDragEnd(DragEndDetails details) {
    if (!_sheetController.isAttached) return;
    final velocity = details.primaryVelocity ?? 0;
    final size = _sheetController.size;
    final double target;
    if (velocity > 700 || size < AdaptivePanel.detailsInitialSize * 0.6) {
      target = 0;
    } else if (velocity < -700) {
      target = AdaptivePanel.detailsMaxSize;
    } else {
      const stops = [
        AdaptivePanel.detailsInitialSize,
        AdaptivePanel.detailsMaxSize,
      ];
      target = stops.reduce(
        (a, b) => (a - size).abs() <= (b - size).abs() ? a : b,
      );
    }
    _sheetController.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = AdaptivePanel.isTablet(context);

    if (isWide) {
      final Widget? sideContent =
          widget.formChild ??
          (widget.detailsBuilder != null
              ? widget.detailsBuilder!(context, null)
              : null);

      return Row(
        children: [
          Expanded(child: widget.mapChild),
          if (sideContent != null)
            Container(
              width: 380,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(left: BorderSide(color: Colors.grey.shade300)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(-2, 0),
                  ),
                ],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: KeyedSubtree(
                  key: ValueKey<Object?>(
                    widget.formChild != null
                        ? widget.formChild!.key
                        : widget.detailsKey,
                  ),
                  child: sideContent,
                ),
              ),
            ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight;

        return Stack(
          children: [
            Positioned.fill(child: widget.mapChild),
            if (widget.detailsBuilder != null && widget.formChild == null)
              NotificationListener<DraggableScrollableNotification>(
                onNotification: (n) {
                  if (n.extent <= 0.05) _dismissSheet();
                  return false;
                },
                child: DraggableScrollableSheet(
                  controller: _sheetController,
                  initialChildSize: AdaptivePanel.detailsInitialSize,
                  minChildSize: 0,
                  maxChildSize: AdaptivePanel.detailsMaxSize,
                  snap: true,
                  snapSizes: const [AdaptivePanel.detailsInitialSize],
                  snapAnimationDuration: const Duration(milliseconds: 260),
                  builder: (context, scrollController) => _IosSheetSurface(
                    key: const Key('details_sheet_surface'),
                    onGrabberDragUpdate: (d) =>
                        _onGrabberDragUpdate(d, maxHeight),
                    onGrabberDragEnd: _onGrabberDragEnd,
                    child: SafeArea(
                      top: false,
                      // One child at a time: both sides of a cross-fade
                      // cannot share the sheet's scroll controller.
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey<Object?>(widget.detailsKey),
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        builder: (context, t, child) => Opacity(
                          opacity: t,
                          child: Transform.translate(
                            offset: Offset(0, 12 * (1 - t)),
                            child: child,
                          ),
                        ),
                        child: widget.detailsBuilder!(
                          context,
                          scrollController,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (widget.formChild != null)
              Positioned.fill(
                top: MediaQuery.paddingOf(context).top + 12,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.08, end: 0.0),
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  builder: (context, slideOffset, child) {
                    return FractionalTranslation(
                      translation: Offset(0, slideOffset),
                      child: child,
                    );
                  },
                  child: _IosSheetSurface(
                    child: SafeArea(top: false, child: widget.formChild!),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _IosSheetSurface extends StatelessWidget {
  final Widget child;
  final GestureDragUpdateCallback? onGrabberDragUpdate;
  final GestureDragEndCallback? onGrabberDragEnd;

  const _IosSheetSurface({
    super.key,
    required this.child,
    this.onGrabberDragUpdate,
    this.onGrabberDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AdaptivePanel.sheetTopRadius),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            spreadRadius: 1,
            offset: Offset(0, -4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      // A Stack + padding (not a Column) so that a sheet dragged almost
      // closed shrinks the content to zero height instead of overflowing,
      // while the scrollable stays mounted and keeps the drag.
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: _grabberHeight),
            child: child,
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _grabberHeight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: onGrabberDragUpdate,
              onVerticalDragEnd: onGrabberDragEnd,
              child: Center(
                child: Container(
                  key: const Key('ios_sheet_grabber'),
                  width: 38,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC7C7CC),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const double _grabberHeight = 23;
}
