import 'dart:math' as math;

import '../../core/geo_utils.dart';
import '../../data/models/manhole.dart';
import '../../data/models/pipe.dart';
import '../../data/models/work_status.dart';
import 'network_graph.dart';

/// One object appearing in the construction replay.
class BuildStep {
  final bool isPipe;
  final String id;
  final String code;

  /// The object's current (real) status — the colour it appears in.
  final WorkStatus status;

  /// Real work start, if the history has one (shown as the replay date).
  final DateTime? at;

  /// Animation length at 1x speed.
  final int durationMs;

  const BuildStep({
    required this.isPipe,
    required this.id,
    required this.code,
    required this.status,
    required this.at,
    required this.durationMs,
  });
}

/// Consecutive steps that fit one close camera frame.
class BuildChunk {
  final int firstStep; // inclusive
  final int lastStep; // inclusive
  final List<({double lat, double lng})> points;

  const BuildChunk({
    required this.firstStep,
    required this.lastStep,
    required this.points,
  });
}

/// The construction replay: the whole network is drawn object by object as
/// one crew would build it — starting at the north-west (top-left) pipe and
/// following the lines (manhole → pipe → next manhole); when a branch ends
/// it continues at the nearest unbuilt pipe. Steps are grouped into
/// camera-sized parts.
class TimelinePlan {
  final List<BuildStep> steps;
  final List<BuildChunk> chunks;

  /// Step index -> chunk index.
  final List<int> chunkOfStep;

  const TimelinePlan({
    required this.steps,
    required this.chunks,
    required this.chunkOfStep,
  });

  static const int manholeMs = 260;
  static const int pipeMinMs = 450;
  static const int pipeMaxMs = 1100;

  /// Max size (m) of one camera part, and max steps in it.
  static const double chunkSpanM = 340;
  static const int chunkMaxSteps = 18;

  bool get isEmpty => steps.isEmpty;

  static TimelinePlan build({
    required Map<String, Manhole> manholes,
    required Map<String, Pipe> pipes,
    List<StatusEvent> events = const [],
  }) {
    final started = <String, DateTime>{};
    for (final e in events) {
      if (e.status != WorkStatus.inProgress) continue;
      final prev = started[e.objectId];
      if (prev == null || e.changedAt.isBefore(prev)) {
        started[e.objectId] = e.changedAt;
      }
    }

    final valid = pipes.values
        .where(
          (p) =>
              manholes.containsKey(p.fromManholeId) &&
              manholes.containsKey(p.toManholeId),
        )
        .toList();
    final order = crewOrder(manholes, valid);

    // Standalone manholes go right after the pipe nearest to them.
    final linked = <String>{
      for (final p in valid) ...[p.fromManholeId, p.toManholeId],
    };
    final afterPipe = <String, List<Manhole>>{};
    final leftovers = <Manhole>[];
    for (final m in manholes.values.where((m) => !linked.contains(m.id))) {
      if (order.isEmpty) {
        leftovers.add(m);
        continue;
      }
      Pipe? best;
      var bestD = double.infinity;
      for (final p in order) {
        final mid = _mid(p, manholes);
        final d = GeoUtils.haversineMeters(m.lat, m.lng, mid.lat, mid.lng);
        if (d < bestD) {
          bestD = d;
          best = p;
        }
      }
      afterPipe.putIfAbsent(best!.id, () => []).add(m);
    }

    final steps = <BuildStep>[];
    final shown = <String>{};
    void addManhole(Manhole m) {
      if (!shown.add(m.id)) return;
      steps.add(
        BuildStep(
          isPipe: false,
          id: m.id,
          code: m.code,
          status: m.status,
          at: started[m.id],
          durationMs: manholeMs,
        ),
      );
    }

    for (final p in order) {
      addManhole(manholes[p.fromManholeId]!);
      steps.add(
        BuildStep(
          isPipe: true,
          id: p.id,
          code: p.code,
          status: p.status,
          at: started[p.id],
          durationMs: (p.lengthM * 3).round().clamp(pipeMinMs, pipeMaxMs),
        ),
      );
      addManhole(manholes[p.toManholeId]!);
      for (final m in afterPipe[p.id] ?? const <Manhole>[]) {
        addManhole(m);
      }
    }
    leftovers.forEach(addManhole);

    // Group into camera parts.
    List<({double lat, double lng})> pointsOf(BuildStep s) {
      if (!s.isPipe) {
        final m = manholes[s.id]!;
        return [(lat: m.lat, lng: m.lng)];
      }
      final p = pipes[s.id]!;
      final a = manholes[p.fromManholeId]!;
      final b = manholes[p.toManholeId]!;
      return [
        (lat: a.lat, lng: a.lng),
        for (final v in p.path) (lat: v[0], lng: v[1]),
        (lat: b.lat, lng: b.lng),
      ];
    }

    final chunks = <BuildChunk>[];
    final chunkOfStep = <int>[];
    var first = 0;
    var pts = <({double lat, double lng})>[];
    for (var i = 0; i < steps.length; i++) {
      final next = [...pts, ...pointsOf(steps[i])];
      final tooBig =
          pts.isNotEmpty &&
          (spanMeters(next) > chunkSpanM || i - first >= chunkMaxSteps);
      if (tooBig) {
        chunks.add(BuildChunk(firstStep: first, lastStep: i - 1, points: pts));
        first = i;
        pts = pointsOf(steps[i]);
      } else {
        pts = next;
      }
      chunkOfStep.add(chunks.length);
    }
    if (pts.isNotEmpty) {
      chunks.add(
        BuildChunk(firstStep: first, lastStep: steps.length - 1, points: pts),
      );
    }

    return TimelinePlan(
      steps: steps,
      chunks: chunks,
      chunkOfStep: chunkOfStep,
    );
  }

  static ({double lat, double lng}) _mid(Pipe p, Map<String, Manhole> m) {
    final a = m[p.fromManholeId]!;
    final b = m[p.toManholeId]!;
    return (lat: (a.lat + b.lat) / 2, lng: (a.lng + b.lng) / 2);
  }

  /// One crew working through the network: start at the pipe nearest the
  /// north-west corner, keep following the line, then the nearest unbuilt
  /// pipe touching the built part, then the nearest anywhere.
  static List<Pipe> crewOrder(Map<String, Manhole> manholes, List<Pipe> pipes) {
    if (pipes.isEmpty) return const [];
    final mids = {for (final p in pipes) p.id: _mid(p, manholes)};
    final at = <String, List<Pipe>>{};
    for (final p in pipes) {
      at.putIfAbsent(p.fromManholeId, () => []).add(p);
      at.putIfAbsent(p.toManholeId, () => []).add(p);
    }
    double dist(({double lat, double lng}) a, ({double lat, double lng}) b) =>
        GeoUtils.haversineMeters(a.lat, a.lng, b.lat, b.lng);

    final maxLat = manholes.values.map((m) => m.lat).reduce(math.max);
    final minLng = manholes.values.map((m) => m.lng).reduce(math.min);
    final corner = (lat: maxLat, lng: minLng);
    var current = pipes.reduce(
      (a, b) => dist(mids[a.id]!, corner) <= dist(mids[b.id]!, corner) ? a : b,
    );

    final order = <Pipe>[];
    final built = <String>{};
    final builtNodes = <String>{};
    while (true) {
      order.add(current);
      built.add(current.id);
      builtNodes
        ..add(current.fromManholeId)
        ..add(current.toManholeId);
      if (built.length == pipes.length) break;
      final last = mids[current.id]!;
      Pipe nearest(Iterable<Pipe> candidates) => candidates.reduce(
        (a, b) => dist(mids[a.id]!, last) <= dist(mids[b.id]!, last) ? a : b,
      );
      final cont = [
        for (final n in [current.toManholeId, current.fromManholeId])
          ...?at[n]?.where((p) => !built.contains(p.id)),
      ];
      if (cont.isNotEmpty) {
        current = nearest(cont);
        continue;
      }
      final touching = [
        for (final n in builtNodes)
          ...?at[n]?.where((p) => !built.contains(p.id)),
      ];
      current = nearest(
        touching.isNotEmpty
            ? touching
            : pipes.where((p) => !built.contains(p.id)),
      );
    }
    return order;
  }

  /// Largest side (m) of the points' bounding box.
  static double spanMeters(List<({double lat, double lng})> pts) {
    if (pts.length < 2) return 0;
    var minLat = pts.first.lat, maxLat = pts.first.lat;
    var minLng = pts.first.lng, maxLng = pts.first.lng;
    for (final p in pts) {
      minLat = math.min(minLat, p.lat);
      maxLat = math.max(maxLat, p.lat);
      minLng = math.min(minLng, p.lng);
      maxLng = math.max(maxLng, p.lng);
    }
    return math.max(
      GeoUtils.haversineMeters(minLat, minLng, maxLat, minLng),
      GeoUtils.haversineMeters(minLat, minLng, minLat, maxLng),
    );
  }

  /// Ids revealed after steps `0..lastIncluded` (inclusive; -1 = none).
  Set<String> revealedThrough(int lastIncluded) => {
    for (var i = 0; i <= lastIncluded && i < steps.length; i++) steps[i].id,
  };
}
