import '../../data/models/manhole.dart';
import '../../data/models/pipe.dart';
import '../../data/models/work_status.dart';

/// Result of tracing the flow through the network from one manhole.
class FlowTrace {
  final String originId;
  final Set<String> downstreamPipes;
  final Set<String> downstreamManholes;
  final Set<String> upstreamPipes;
  final Set<String> upstreamManholes;

  const FlowTrace({
    required this.originId,
    required this.downstreamPipes,
    required this.downstreamManholes,
    required this.upstreamPipes,
    required this.upstreamManholes,
  });

  bool get isEmpty => downstreamPipes.isEmpty && upstreamPipes.isEmpty;
}

/// Pipe direction is `from → to` (flow direction, LLD §1.1).
class NetworkGraph {
  const NetworkGraph._();

  static FlowTrace trace(String manholeId, Iterable<Pipe> pipes) {
    final outgoing = <String, List<Pipe>>{};
    final incoming = <String, List<Pipe>>{};
    for (final p in pipes) {
      outgoing.putIfAbsent(p.fromManholeId, () => []).add(p);
      incoming.putIfAbsent(p.toManholeId, () => []).add(p);
    }

    (Set<String>, Set<String>) walk(
      Map<String, List<Pipe>> edges,
      String Function(Pipe) next,
    ) {
      final pipeIds = <String>{};
      final manholeIds = <String>{};
      final queue = [manholeId];
      final seen = {manholeId};
      while (queue.isNotEmpty) {
        final current = queue.removeLast();
        for (final p in edges[current] ?? const <Pipe>[]) {
          pipeIds.add(p.id);
          final n = next(p);
          if (seen.add(n)) {
            manholeIds.add(n);
            queue.add(n);
          }
        }
      }
      return (pipeIds, manholeIds);
    }

    final down = walk(outgoing, (p) => p.toManholeId);
    final up = walk(incoming, (p) => p.fromManholeId);
    return FlowTrace(
      originId: manholeId,
      downstreamPipes: down.$1,
      downstreamManholes: down.$2,
      upstreamPipes: up.$1,
      upstreamManholes: up.$2,
    );
  }

  /// Total length (m) of the given pipes.
  static double lengthOf(Set<String> pipeIds, Map<String, Pipe> pipes) =>
      pipeIds.fold(0.0, (sum, id) => sum + (pipes[id]?.lengthM ?? 0));

  /// Manholes in [ids] ordered by nothing in particular; helper for labels.
  static List<Manhole> manholesOf(
    Set<String> ids,
    Map<String, Manhole> manholes,
  ) => [
    for (final id in ids)
      if (manholes[id] != null) manholes[id]!,
  ];
}

/// One row of `status_events`.
class StatusEvent {
  final String objectType; // 'manhole' | 'pipe'
  final String objectId;
  final WorkStatus? status; // null = deleted
  final DateTime changedAt;

  const StatusEvent({
    required this.objectType,
    required this.objectId,
    required this.status,
    required this.changedAt,
  });

  factory StatusEvent.fromJson(Map<String, dynamic> json) => StatusEvent(
    objectType: json['object_type'] as String,
    objectId: json['object_id'] as String,
    status: switch (json['status'] as String?) {
      'planned' => WorkStatus.planned,
      'in_progress' => WorkStatus.inProgress,
      'completed' => WorkStatus.completed,
      _ => null,
    },
    changedAt: DateTime.parse(json['changed_at'] as String),
  );
}

/// Network state at a moment in time, built from the status history.
class NetworkSnapshot {
  final Map<String, Manhole> manholes;
  final Map<String, Pipe> pipes;

  const NetworkSnapshot(this.manholes, this.pipes);

  /// Objects without any event at or before [at] did not exist yet and are
  /// left out; others take the status of their latest event (null = deleted).
  static NetworkSnapshot at(
    DateTime at,
    Map<String, Manhole> manholes,
    Map<String, Pipe> pipes,
    List<StatusEvent> events,
  ) {
    final latest = <String, StatusEvent>{};
    for (final e in events) {
      if (e.changedAt.isAfter(at)) continue;
      final prev = latest[e.objectId];
      if (prev == null || !e.changedAt.isBefore(prev.changedAt)) {
        latest[e.objectId] = e;
      }
    }
    final ms = <String, Manhole>{};
    for (final m in manholes.values) {
      final s = latest[m.id]?.status;
      if (s != null) ms[m.id] = m.copyWith(status: s);
    }
    final ps = <String, Pipe>{};
    for (final p in pipes.values) {
      final s = latest[p.id]?.status;
      if (s != null &&
          ms.containsKey(p.fromManholeId) &&
          ms.containsKey(p.toManholeId)) {
        ps[p.id] = p.copyWith(status: s);
      }
    }
    return NetworkSnapshot(ms, ps);
  }
}
