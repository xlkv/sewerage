import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models/pipe.dart';
import '../../data/models/work_status.dart';

class CrossSectionPipe {
  final String code;
  final int diameterMm;
  final WorkStatus status;

  const CrossSectionPipe(this.code, this.diameterMm, this.status);

  factory CrossSectionPipe.of(Pipe p) =>
      CrossSectionPipe(p.code, p.diameterMm, p.status);
}

/// Engineering-style vertical section of a manhole: ground, shaft sized by
/// depth/diameter, incoming pipes on the left and outgoing on the right, with
/// slowly flowing water.
class ManholeCrossSection extends StatefulWidget {
  final double? depthM;
  final double? diameterM;
  final WorkStatus status;
  final List<CrossSectionPipe> incoming;
  final List<CrossSectionPipe> outgoing;

  const ManholeCrossSection({
    super.key,
    required this.depthM,
    required this.diameterM,
    required this.status,
    required this.incoming,
    required this.outgoing,
  });

  @override
  State<ManholeCrossSection> createState() => _ManholeCrossSectionState();
}

class _ManholeCrossSectionState extends State<ManholeCrossSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _flow.stop();
    } else if (!_flow.isAnimating) {
      _flow.repeat();
    }
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _CrossSectionPainter(
            flow: _flow,
            depthM: widget.depthM,
            diameterM: widget.diameterM,
            status: widget.status,
            incoming: widget.incoming,
            outgoing: widget.outgoing,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _CrossSectionPainter extends CustomPainter {
  final Animation<double> flow;
  final double? depthM;
  final double? diameterM;
  final WorkStatus status;
  final List<CrossSectionPipe> incoming;
  final List<CrossSectionPipe> outgoing;

  _CrossSectionPainter({
    required this.flow,
    required this.depthM,
    required this.diameterM,
    required this.status,
    required this.incoming,
    required this.outgoing,
  }) : super(repaint: flow);

  static const _soil = Color(0xFFEDE7DC);
  static const _soilLine = Color(0xFFD6CCBC);
  static const _water = Color(0xFF38BDF8);

  @override
  void paint(Canvas canvas, Size size) {
    final statusColor = AppColors.forStatus(status);
    final depth = depthM ?? 2.0;
    final diameter = diameterM ?? 1.0;

    const groundY = 34.0;
    final shaftDepthPx = (depth / 4.0 * 130).clamp(70.0, 150.0);
    final bottomY = groundY + shaftDepthPx;
    final shaftWidth = (diameter / 1.5 * 74).clamp(44.0, 96.0);
    final cx = size.width / 2;
    final shaftLeft = cx - shaftWidth / 2;
    final shaftRight = cx + shaftWidth / 2;

    // Soil with hatching.
    final soilRect = Rect.fromLTRB(0, groundY, size.width, size.height);
    canvas.drawRect(soilRect, Paint()..color = _soil);
    final hatch = Paint()
      ..color = _soilLine
      ..strokeWidth = 1;
    for (var x = -size.height; x < size.width; x += 14) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height - groundY, groundY),
        hatch,
      );
    }
    canvas.drawLine(
      const Offset(0, groundY),
      Offset(size.width, groundY),
      Paint()
        ..color = AppColors.muted
        ..strokeWidth = 2,
    );

    // Pipes (behind shaft walls).
    double pipeHeight(int mm) => (mm / 10).clamp(9.0, 30.0);
    void drawPipe(CrossSectionPipe p, int index, bool left) {
      final h = pipeHeight(p.diameterMm);
      final y = bottomY - 4 - h - index * (h + 8);
      final rect = left
          ? Rect.fromLTRB(0, y, shaftLeft, y + h)
          : Rect.fromLTRB(shaftRight, y, size.width, y + h);
      final color = AppColors.forStatus(p.status);
      canvas.drawRect(rect, Paint()..color = Colors.white);
      // Water inside (lower 55%), with dashes moving left → right.
      final waterRect = Rect.fromLTRB(
        rect.left,
        rect.top + h * 0.45,
        rect.right,
        rect.bottom,
      );
      canvas.drawRect(waterRect, Paint()..color = _water.withValues(alpha: 0.35));
      final dash = Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      final period = 16.0;
      final offset = flow.value * period;
      final wy = waterRect.center.dy;
      canvas.save();
      canvas.clipRect(waterRect);
      for (var x = rect.left - period + offset; x < rect.right; x += period) {
        canvas.drawLine(Offset(x, wy), Offset(x + 6, wy), dash);
      }
      canvas.restore();
      canvas.drawRect(
        rect,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      _text(
        canvas,
        '${p.code} · Ø${p.diameterMm}',
        Offset(left ? 8 : size.width - 8, y - 4),
        align: left ? TextAlign.left : TextAlign.right,
        anchorBottom: true,
      );
    }

    for (var i = 0; i < math.min(2, incoming.length); i++) {
      drawPipe(incoming[i], i, true);
    }
    for (var i = 0; i < math.min(2, outgoing.length); i++) {
      drawPipe(outgoing[i], i, false);
    }
    if (incoming.length > 2) {
      _text(canvas, '+${incoming.length - 2}', Offset(8, bottomY + 14));
    }
    if (outgoing.length > 2) {
      _text(
        canvas,
        '+${outgoing.length - 2}',
        Offset(size.width - 8, bottomY + 14),
        align: TextAlign.right,
      );
    }

    // Shaft interior, water at the bottom, walls.
    final shaft = Rect.fromLTRB(shaftLeft, groundY, shaftRight, bottomY);
    canvas.drawRect(shaft, Paint()..color = Colors.white);
    final waterTop = bottomY - 10 - 3 * math.sin(flow.value * 2 * math.pi);
    canvas.drawRect(
      Rect.fromLTRB(shaftLeft, waterTop, shaftRight, bottomY),
      Paint()..color = _water.withValues(alpha: 0.35),
    );
    // Step irons.
    final rungs = Paint()
      ..color = AppColors.line
      ..strokeWidth = 2;
    for (var y = groundY + 16; y < bottomY - 14; y += 16) {
      canvas.drawLine(
        Offset(cx - shaftWidth * 0.18, y),
        Offset(cx + shaftWidth * 0.18, y),
        rungs,
      );
    }
    final wall = Paint()
      ..color = AppColors.ink
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(shaftLeft, groundY)
        ..lineTo(shaftLeft, bottomY)
        ..lineTo(shaftRight, bottomY)
        ..lineTo(shaftRight, groundY),
      wall,
    );

    // Cover.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(shaftLeft - 8, groundY - 6, shaftRight + 8, groundY + 1),
        const Radius.circular(3),
      ),
      Paint()..color = statusColor,
    );

    // Depth dimension (right of shaft) and diameter (below).
    final dim = Paint()
      ..color = AppColors.brand
      ..strokeWidth = 1.4;
    final dx = shaftRight + 18;
    canvas.drawLine(Offset(dx, groundY), Offset(dx, bottomY), dim);
    canvas.drawLine(Offset(dx - 4, groundY), Offset(dx + 4, groundY), dim);
    canvas.drawLine(Offset(dx - 4, bottomY), Offset(dx + 4, bottomY), dim);
    _text(
      canvas,
      depthM == null ? '—' : '${depthM!.toStringAsFixed(2)} m',
      Offset(dx + 6, (groundY + bottomY) / 2 - 7),
      color: AppColors.brand,
      bold: true,
    );
    final dy = bottomY + 12;
    canvas.drawLine(Offset(shaftLeft, dy), Offset(shaftRight, dy), dim);
    canvas.drawLine(Offset(shaftLeft, dy - 4), Offset(shaftLeft, dy + 4), dim);
    canvas.drawLine(Offset(shaftRight, dy - 4), Offset(shaftRight, dy + 4), dim);
    _text(
      canvas,
      diameterM == null ? 'Ø —' : 'Ø ${diameterM!.toStringAsFixed(2)} m',
      Offset(cx, dy + 4),
      align: TextAlign.center,
      color: AppColors.brand,
      bold: true,
    );

    _text(canvas, 'Yer sathi', const Offset(8, groundY - 18), color: AppColors.muted);
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at, {
    TextAlign align = TextAlign.left,
    Color color = AppColors.ink,
    bool bold = false,
    bool anchorBottom = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          color: color,
          fontSize: 11,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    var x = at.dx;
    if (align == TextAlign.right) x -= tp.width;
    if (align == TextAlign.center) x -= tp.width / 2;
    final y = anchorBottom ? at.dy - tp.height : at.dy;
    tp.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant _CrossSectionPainter old) =>
      old.depthM != depthM ||
      old.diameterM != diameterM ||
      old.status != status ||
      old.incoming != incoming ||
      old.outgoing != outgoing;
}
