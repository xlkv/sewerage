import 'package:flutter_test/flutter_test.dart';
import 'package:turon/core/geo_utils.dart';
import 'package:turon/data/models/manhole.dart';
import 'package:turon/data/models/pipe.dart';
import 'package:turon/features/manhole/insert_manhole_sheet.dart';
import 'package:turon/features/map/map_controller.dart';
import 'package:turon/features/map/map_mode.dart';
import 'package:turon/features/map/network_graph.dart';
import 'package:turon/features/section/section_stats.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Pipe _pipe(String id, String a, String b, double len, {int d = 200}) => Pipe(
  id: id,
  code: id,
  fromManholeId: a,
  toManholeId: b,
  diameterMm: d,
  lengthAutoM: len,
);

void main() {
  group('splitPolyline', () {
    // East 0.01° then north 0.01° (an L); each leg ≈ 1.1 km.
    final pts = [
      (lat: 0.0, lng: 0.0),
      (lat: 0.0, lng: 0.01),
      (lat: 0.01, lng: 0.01),
    ];

    test('point on the first leg keeps the corner on the far side', () {
      final s = GeoUtils.splitPolyline(pts, 100);
      expect(s.lat, closeTo(0, 1e-9));
      expect(
        GeoUtils.haversineMeters(0, 0, s.lat, s.lng),
        closeTo(100, 0.5),
      );
      expect(s.before, isEmpty);
      expect(s.after, [
        [0.0, 0.01],
      ]);
    });

    test('point past the corner keeps it before', () {
      final leg = GeoUtils.polylineMeters(pts.sublist(0, 2));
      final s = GeoUtils.splitPolyline(pts, leg + 50);
      expect(s.lng, closeTo(0.01, 1e-9));
      expect(s.before, [
        [0.0, 0.01],
      ]);
      expect(s.after, isEmpty);
    });
  });

  test('insertPointOnPipe measures from the chosen end', () {
    const a = Manhole(id: 'a', code: 'K-1', lat: 0, lng: 0);
    const b = Manhole(id: 'b', code: 'K-2', lat: 0, lng: 0.01);
    final p = _pipe('p', 'a', 'b', 1113);
    final fromB = insertPointOnPipe(
      pipe: p,
      pipeFrom: a,
      pipeTo: b,
      fromManholeId: 'b',
      meters: 100,
    );
    expect(GeoUtils.haversineMeters(0, 0.01, fromB.lat, fromB.lng),
        closeTo(100, 0.5));
  });

  test('shortestPath ignores flow direction and picks the shorter way', () {
    final pipes = [
      _pipe('ab', 'a', 'b', 10),
      _pipe('cb', 'c', 'b', 10), // against the walk direction
      _pipe('ac', 'a', 'c', 50),
      _pipe('xy', 'x', 'y', 5),
    ];
    expect(NetworkPaths.shortestPath('a', 'c', pipes), ['ab', 'cb']);
    expect(NetworkPaths.shortestPath('a', 'x', pipes), isNull);
    expect(NetworkPaths.shortestPath('a', 'a', pipes), isEmpty);
  });

  test('SectionStats groups lengths by diameter', () {
    final all = {
      'p1': _pipe('p1', 'a', 'b', 100, d: 315),
      'p2': _pipe('p2', 'b', 'c', 50, d: 200),
      'p3': _pipe('p3', 'c', 'd', 25, d: 315),
    };
    final ids = {'p1', 'p2', 'p3'};
    final manholes = SectionStats.manholesOf(ids, all);
    final s = SectionStats.of(
      pipeIds: ids,
      manholeCount: manholes.length,
      allPipes: all,
    );
    expect(s.lengthM, 175);
    expect(s.manholeCount, 4);
    expect(s.byDiameter.first.diameterMm, 315);
    expect(s.byDiameter.first.meters, 125);
    expect(s.byDiameter.first.count, 2);
  });

  test('section mode: start, end adds the path, pipe tap toggles', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(mapControllerProvider.notifier);
    final pipes = [_pipe('ab', 'a', 'b', 10), _pipe('bc', 'b', 'c', 10)];
    n.startSection();
    n.onManholeTap('a', existingPipes: pipes);
    n.onManholeTap('c', existingPipes: pipes);
    var m = c.read(mapControllerProvider).mode as SectionMode;
    expect(m.pipeIds, {'ab', 'bc'});
    n.onPipeTap('bc');
    m = c.read(mapControllerProvider).mode as SectionMode;
    expect(m.pipeIds, {'ab'});
    n.onManholeTap('z', existingPipes: pipes);
    expect(c.read(mapControllerProvider).snackbarMessage,
        MapController.notConnectedMessage);
  });
}
