import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:turon/data/models/manhole.dart';
import 'package:turon/data/models/pipe.dart';
import 'package:turon/data/models/work_status.dart';
import 'package:turon/features/map/feature_providers.dart';
import 'package:turon/features/map/map_mode.dart';
import 'package:turon/features/map/map_overlays.dart';
import 'package:turon/features/report/network_report.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final manholes = {
    'a': const Manhole(id: 'a', code: 'K-1', lat: 38.86, lng: 65.78),
    'b': const Manhole(
      id: 'b',
      code: 'K-12',
      lat: 38.861,
      lng: 65.79,
      status: WorkStatus.completed,
    ),
  };
  final pipes = {
    'p': const Pipe(
      id: 'p',
      code: 'Q-12',
      fromManholeId: 'a',
      toManholeId: 'b',
      diameterMm: 315,
      lengthAutoM: 870,
    ),
  };

  group('searchNetwork', () {
    test('a bare number finds both K-12 and Q-12, exact matches first', () {
      final r = searchNetwork('12', manholes, pipes);
      expect(r.map((e) => e.code), ['K-12', 'Q-12']);
      expect(r.last.selection, isA<PipeSelection>());
    });

    test('case-insensitive full code', () {
      final r = searchNetwork('k-1', manholes, pipes);
      expect(r.first.code, 'K-1');
    });

    test('empty query returns nothing', () {
      expect(searchNetwork('  ', manholes, pipes), isEmpty);
    });
  });

  group('TimelineState', () {
    test('progress is 0 at start and 1 at end', () {
      final start = DateTime(2026, 10, 1);
      final end = DateTime(2026, 10, 11);
      expect(TimelineState(start: start, end: end, at: start).progress, 0);
      expect(TimelineState(start: start, end: end, at: end).progress, 1);
    });
  });

  test('PDF report builds with Uzbek text and schematic', () async {
    await initializeDateFormatting('uz');
    final bytes = await NetworkReport.build(
      manholes: manholes,
      pipes: pipes,
      masters: const [],
      now: DateTime(2026, 10, 20),
    );
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
