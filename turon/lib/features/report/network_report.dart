import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/geo_utils.dart';
import '../../core/theme.dart';
import '../../data/models/manhole.dart';
import '../../data/models/master.dart';
import '../../data/models/pipe.dart';
import '../../data/models/work_status.dart';
import '../map/network_stats_card.dart';

/// One-tap PDF report: summary, vector schematic of the network, tables.
class NetworkReport {
  const NetworkReport._();

  static PdfColor _c(int argb) => PdfColor.fromInt(argb);
  static final _brand = _c(AppColors.brand.toARGB32());
  static final _ink = _c(AppColors.ink.toARGB32());
  static final _muted = _c(AppColors.muted.toARGB32());
  static final _line = _c(AppColors.line.toARGB32());
  static PdfColor _status(WorkStatus s) =>
      _c(AppColors.forStatus(s).toARGB32());

  static Future<Uint8List> build({
    required Map<String, Manhole> manholes,
    required Map<String, Pipe> pipes,
    required List<Master> masters,
    DateTime? now,
  }) async {
    final date = now ?? DateTime.now();
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Manrope-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Manrope-ExtraBold.ttf'),
    );
    final stats = NetworkStats.from(manholes.values, pipes.values);
    final total = stats.totalMeters;
    final done = stats.meters[WorkStatus.completed]!;
    final masterNames = {for (final m in masters) m.id: m.fullName};

    final sortedPipes = pipes.values.toList()
      ..sort((a, b) => _codeNum(a.code).compareTo(_codeNum(b.code)));
    final sortedManholes = manholes.values.toList()
      ..sort((a, b) => _codeNum(a.code).compareTo(_codeNum(b.code)));

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      title: 'Turon — tarmoq hisoboti',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${ctx.pageNumber} / ${ctx.pagesCount}',
            style: pw.TextStyle(color: _muted, fontSize: 9),
          ),
        ),
        build: (ctx) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Turon',
                      style: pw.TextStyle(
                        color: _brand,
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Kanalizatsiya tarmog\'i hisoboti',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Text(
                DateFormat('d-MMMM, yyyy · HH:mm', 'uz').format(date),
                style: pw.TextStyle(color: _muted, fontSize: 10),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              _kpi('Jami tarmoq', GeoUtils.formatLength(total)),
              pw.SizedBox(width: 10),
              _kpi(
                'Tugallangan',
                total <= 0 ? '0%' : '${(done / total * 100).round()}%',
              ),
              pw.SizedBox(width: 10),
              _kpi('Kolodetslar', '${manholes.length}'),
              pw.SizedBox(width: 10),
              _kpi('Quvurlar', '${pipes.length}'),
            ],
          ),
          pw.SizedBox(height: 14),
          _statusBar(stats),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: ['Holat', 'Quvurlar', 'Uzunlik', 'Kolodetslar'],
            data: [
              for (final s in WorkStatus.values)
                [
                  s.label,
                  '${stats.pipes[s]}',
                  GeoUtils.formatLength(stats.meters[s]!),
                  '${stats.manholes[s]}',
                ],
            ],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(color: _brand),
            cellAlignments: {
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
            border: pw.TableBorder.all(color: _line),
          ),
          pw.SizedBox(height: 18),
          _sectionTitle('Tarmoq sxemasi'),
          _schematic(manholes, pipes),
          pw.SizedBox(height: 6),
          _legend(),
          pw.SizedBox(height: 18),
          _sectionTitle('Quvurlar'),
          pw.TableHelper.fromTextArray(
            headers: ['Kod', 'Yo\'nalish', 'Ø, mm', 'Uzunlik', 'Holat'],
            data: [
              for (final p in sortedPipes)
                [
                  p.code,
                  '${manholes[p.fromManholeId]?.code ?? '?'} → '
                      '${manholes[p.toManholeId]?.code ?? '?'}',
                  '${p.diameterMm}',
                  GeoUtils.formatLength(p.lengthM) +
                      (p.lengthManualM != null ? ' *' : ''),
                  p.status.label,
                ],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: pw.BoxDecoration(color: _line),
            cellStyle: const pw.TextStyle(fontSize: 9),
            border: pw.TableBorder.all(color: _line),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text(
              '* uzunlik qo\'lda kiritilgan',
              style: pw.TextStyle(color: _muted, fontSize: 8),
            ),
          ),
          pw.SizedBox(height: 18),
          _sectionTitle('Kolodetslar'),
          pw.TableHelper.fromTextArray(
            headers: ['Kod', 'Chuqurlik', 'Diametr', 'Usta', 'Holat'],
            data: [
              for (final m in sortedManholes)
                [
                  m.code,
                  m.heightM == null ? '—' : '${m.heightM!.toStringAsFixed(2)} m',
                  m.diameterM == null
                      ? '—'
                      : '${m.diameterM!.toStringAsFixed(2)} m',
                  masterNames[m.masterId] ?? '—',
                  m.status.label,
                ],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: pw.BoxDecoration(color: _line),
            cellStyle: const pw.TextStyle(fontSize: 9),
            border: pw.TableBorder.all(color: _line),
          ),
        ],
      ),
    );
    return doc.save();
  }

  static int _codeNum(String code) =>
      int.tryParse(code.replaceAll(RegExp(r'\D'), '')) ?? 1 << 30;

  static pw.Widget _sectionTitle(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 13,
        fontWeight: pw.FontWeight.bold,
        color: _ink,
      ),
    ),
  );

  static pw.Widget _kpi(String label, String value) => pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _line),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(color: _muted, fontSize: 9)),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
        ],
      ),
    ),
  );

  static pw.Widget _statusBar(NetworkStats stats) {
    final total = stats.totalMeters;
    if (total <= 0) return pw.SizedBox();
    return pw.ClipRRect(
      horizontalRadius: 4,
      verticalRadius: 4,
      child: pw.Row(
        children: [
          for (final s in [
            WorkStatus.completed,
            WorkStatus.inProgress,
            WorkStatus.planned,
          ])
            if (stats.meters[s]! > 0)
              pw.Expanded(
                flex: math.max(1, (stats.meters[s]! / total * 1000).round()),
                child: pw.Container(height: 8, color: _status(s)),
              ),
        ],
      ),
    );
  }

  static pw.Widget _legend() => pw.Row(
    children: [
      for (final s in WorkStatus.values) ...[
        pw.Container(width: 14, height: 4, color: _status(s)),
        pw.SizedBox(width: 4),
        pw.Text(s.label, style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(width: 14),
      ],
      pw.Text(
        'Chiziq yo\'nalishi = oqim yo\'nalishi',
        style: pw.TextStyle(fontSize: 9, color: _muted),
      ),
    ],
  );

  /// Equirectangular projection of the network into a fixed box.
  static pw.Widget _schematic(
    Map<String, Manhole> manholes,
    Map<String, Pipe> pipes,
  ) {
    const width = 531.0; // A4 width minus margins
    const height = 300.0;
    const pad = 22.0;
    if (manholes.isEmpty) {
      return pw.Container(
        height: 60,
        alignment: pw.Alignment.center,
        child: pw.Text('Ma\'lumot yo\'q', style: pw.TextStyle(color: _muted)),
      );
    }
    final lats = manholes.values.map((m) => m.lat);
    final lngs = manholes.values.map((m) => m.lng);
    final minLat = lats.reduce(math.min), maxLat = lats.reduce(math.max);
    final minLng = lngs.reduce(math.min), maxLng = lngs.reduce(math.max);
    final kx = math.cos((minLat + maxLat) / 2 * math.pi / 180);
    final spanX = math.max((maxLng - minLng) * kx, 1e-6);
    final spanY = math.max(maxLat - minLat, 1e-6);
    final scale = math.min((width - 2 * pad) / spanX, (height - 2 * pad) / spanY);
    final offX = (width - spanX * scale) / 2;
    final offY = (height - spanY * scale) / 2;
    // PDF y axis points up.
    PdfPoint project(double lat, double lng) => PdfPoint(
      offX + (lng - minLng) * kx * scale,
      offY + (lat - minLat) * scale,
    );

    final labels = manholes.length <= 80;
    return pw.Container(
      width: width,
      height: height,
      decoration: pw.BoxDecoration(
        color: _c(0xFFF8FAFC),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _line),
      ),
      child: pw.Stack(
        children: [
          pw.CustomPaint(
            size: const PdfPoint(width, height),
            painter: (canvas, size) {
              for (final p in pipes.values) {
                final a = manholes[p.fromManholeId];
                final b = manholes[p.toManholeId];
                if (a == null || b == null) continue;
                final pts = [
                  project(a.lat, a.lng),
                  for (final v in p.path) project(v[0], v[1]),
                  project(b.lat, b.lng),
                ];
                canvas
                  ..setStrokeColor(_status(p.status))
                  ..setLineWidth(p.diameterMm >= 315 ? 3 : 2)
                  ..moveTo(pts.first.x, pts.first.y);
                for (final q in pts.skip(1)) {
                  canvas.lineTo(q.x, q.y);
                }
                canvas.strokePath();
                // Small arrowhead at 60% of the pipe's drawn length.
                var total = 0.0;
                for (var i = 0; i < pts.length - 1; i++) {
                  total += math.sqrt(
                    math.pow(pts[i + 1].x - pts[i].x, 2) +
                        math.pow(pts[i + 1].y - pts[i].y, 2),
                  );
                }
                var mx = pts.first.x, my = pts.first.y, ang = 0.0;
                var acc = 0.0;
                for (var i = 0; i < pts.length - 1; i++) {
                  final dx = pts[i + 1].x - pts[i].x;
                  final dy = pts[i + 1].y - pts[i].y;
                  final seg = math.sqrt(dx * dx + dy * dy);
                  if (acc + seg >= total * 0.6 || i == pts.length - 2) {
                    final t = seg == 0 ? 0.0 : (total * 0.6 - acc) / seg;
                    mx = pts[i].x + dx * t;
                    my = pts[i].y + dy * t;
                    ang = math.atan2(dy, dx);
                    break;
                  }
                  acc += seg;
                }
                const len = 6.0;
                canvas
                  ..setFillColor(_status(p.status))
                  ..moveTo(mx + len * math.cos(ang), my + len * math.sin(ang))
                  ..lineTo(
                    mx + len * math.cos(ang + 2.5),
                    my + len * math.sin(ang + 2.5),
                  )
                  ..lineTo(
                    mx + len * math.cos(ang - 2.5),
                    my + len * math.sin(ang - 2.5),
                  )
                  ..closePath()
                  ..fillPath();
              }
              for (final m in manholes.values) {
                final p = project(m.lat, m.lng);
                canvas
                  ..setFillColor(PdfColors.white)
                  ..drawEllipse(p.x, p.y, 4.5, 4.5)
                  ..fillPath()
                  ..setStrokeColor(_status(m.status))
                  ..setLineWidth(2)
                  ..drawEllipse(p.x, p.y, 4.5, 4.5)
                  ..strokePath();
              }
            },
          ),
          if (labels)
            for (final m in manholes.values)
              pw.Positioned(
                left: project(m.lat, m.lng).x + 6,
                top: height - project(m.lat, m.lng).y - 12,
                child: pw.Text(
                  m.code,
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
