import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turon/data/models/manhole.dart';
import 'package:turon/data/models/pipe.dart';
import 'package:turon/data/models/work_status.dart';
import 'package:turon/features/map/feature_providers.dart';
import 'package:turon/features/map/timeline_plan.dart';

void main() {
  // a(north-west) → b → c close together; d → e far away (second part);
  // s is a standalone manhole near b.
  final manholes = {
    'a': const Manhole(id: 'a', code: 'K-1', lat: 38.861, lng: 65.78),
    'b': const Manhole(id: 'b', code: 'K-2', lat: 38.8605, lng: 65.78, status: WorkStatus.completed),
    'c': const Manhole(id: 'c', code: 'K-3', lat: 38.860, lng: 65.78),
    'd': const Manhole(id: 'd', code: 'K-4', lat: 38.80, lng: 65.90),
    'e': const Manhole(id: 'e', code: 'K-5', lat: 38.7995, lng: 65.90),
    's': const Manhole(id: 's', code: 'K-6', lat: 38.8605, lng: 65.7802),
  };
  final pipes = {
    'p2': const Pipe(id: 'p2', code: 'Q-2', fromManholeId: 'b', toManholeId: 'c', diameterMm: 200, lengthAutoM: 55),
    'p1': const Pipe(id: 'p1', code: 'Q-1', fromManholeId: 'a', toManholeId: 'b', diameterMm: 200, lengthAutoM: 55, status: WorkStatus.completed),
    'p3': const Pipe(id: 'p3', code: 'Q-3', fromManholeId: 'd', toManholeId: 'e', diameterMm: 200, lengthAutoM: 55),
  };
  final plan = TimelinePlan.build(manholes: manholes, pipes: pipes);

  test('every object is built once, starting north-west, following the line', () {
    expect(plan.steps.map((s) => s.id), ['a', 'p1', 'b', 's', 'p2', 'c', 'd', 'p3', 'e']);
    expect(plan.steps.length, manholes.length + pipes.length);
  });

  test('objects keep their real status (planned ones too)', () {
    expect(plan.steps.firstWhere((s) => s.id == 'p1').status, WorkStatus.completed);
    expect(plan.steps.firstWhere((s) => s.id == 'p3').status, WorkStatus.planned);
  });

  test('far-away work starts a new camera part', () {
    expect(plan.chunks.length, 2);
    expect(plan.chunkOfStep, [0, 0, 0, 0, 0, 0, 1, 1, 1]);
  });

  test('revealedThrough lists steps built so far', () {
    expect(plan.revealedThrough(-1), isEmpty);
    expect(plan.revealedThrough(1), {'a', 'p1'});
  });

  test('player: move, build each step, move to next part, finale, done', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(timelineProvider.notifier);
    n.open(plan);
    TimelineState s() => container.read(timelineProvider)!;
    expect(s().phase, TimelinePhase.moving);
    expect(s().speed, 2);
    final seen = <(int, TimelinePhase)>{};
    for (var i = 0; i < 3000 && s().phase != TimelinePhase.done; i++) {
      n.advance(const Duration(milliseconds: 20));
      seen.add((s().step, s().phase));
    }
    expect(s().phase, TimelinePhase.done);
    expect(s().progress, 1);
    expect(seen.contains((6, TimelinePhase.moving)), isTrue, reason: 'camera flies to part 2 before step 6');
    expect(seen.contains((9, TimelinePhase.finale)), isTrue);
  });
}
