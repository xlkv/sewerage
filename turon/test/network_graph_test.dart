import 'package:flutter_test/flutter_test.dart';
import 'package:turon/data/models/manhole.dart';
import 'package:turon/data/models/pipe.dart';
import 'package:turon/data/models/work_status.dart';
import 'package:turon/features/map/network_graph.dart';

Manhole mh(String id) => Manhole(id: id, code: id, lat: 0, lng: 0);
Pipe pipe(String id, String from, String to, {double len = 10}) => Pipe(
  id: id,
  code: id,
  fromManholeId: from,
  toManholeId: to,
  diameterMm: 200,
  lengthAutoM: len,
);

void main() {
  // e → b, a → b → c → d → g, f → c
  final pipes = [
    pipe('p1', 'a', 'b'),
    pipe('p2', 'b', 'c'),
    pipe('p3', 'c', 'd'),
    pipe('p4', 'e', 'b'),
    pipe('p5', 'f', 'c'),
    pipe('p6', 'd', 'g'),
  ];

  test('downstream follows from→to to the outfall', () {
    final t = NetworkGraph.trace('b', pipes);
    expect(t.downstreamPipes, {'p2', 'p3', 'p6'});
    expect(t.downstreamManholes, {'c', 'd', 'g'});
  });

  test('upstream collects every pipe flowing into the manhole', () {
    final t = NetworkGraph.trace('c', pipes);
    expect(t.upstreamPipes, {'p2', 'p1', 'p4', 'p5'});
    expect(t.upstreamManholes, {'b', 'a', 'e', 'f'});
  });

  test('cycles do not loop forever', () {
    final t = NetworkGraph.trace('x', [pipe('q1', 'x', 'y'), pipe('q2', 'y', 'x')]);
    expect(t.downstreamPipes, {'q1', 'q2'});
  });

  test('lengthOf sums pipe lengths', () {
    final map = {for (final p in pipes) p.id: p};
    expect(NetworkGraph.lengthOf({'p1', 'p2'}, map), 20);
  });

  group('NetworkSnapshot.at', () {
    final t0 = DateTime(2026, 10, 1);
    final manholes = {for (final id in ['a', 'b']) id: mh(id)};
    final pipeMap = {'p1': pipe('p1', 'a', 'b')};
    final events = [
      StatusEvent(objectType: 'manhole', objectId: 'a', status: WorkStatus.planned, changedAt: t0),
      StatusEvent(objectType: 'manhole', objectId: 'b', status: WorkStatus.planned, changedAt: t0.add(const Duration(days: 2))),
      StatusEvent(objectType: 'pipe', objectId: 'p1', status: WorkStatus.planned, changedAt: t0.add(const Duration(days: 2))),
      StatusEvent(objectType: 'manhole', objectId: 'a', status: WorkStatus.completed, changedAt: t0.add(const Duration(days: 5))),
      StatusEvent(objectType: 'manhole', objectId: 'b', status: null, changedAt: t0.add(const Duration(days: 9))),
    ];

    test('objects not created yet are hidden', () {
      final s = NetworkSnapshot.at(t0.add(const Duration(days: 1)), manholes, pipeMap, events);
      expect(s.manholes.keys, ['a']);
      expect(s.pipes, isEmpty);
    });

    test('latest status at that time is used', () {
      final s = NetworkSnapshot.at(t0.add(const Duration(days: 6)), manholes, pipeMap, events);
      expect(s.manholes['a']!.status, WorkStatus.completed);
      expect(s.pipes.keys, ['p1']);
    });

    test('deleted objects disappear with their pipes', () {
      final s = NetworkSnapshot.at(t0.add(const Duration(days: 10)), manholes, pipeMap, events);
      expect(s.manholes.keys, ['a']);
      expect(s.pipes, isEmpty);
    });
  });
}
