import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/auth_repo.dart';
import 'network_graph.dart';
import 'timeline_plan.dart';

/// Full status history, loaded page by page: the API returns at most 1000
/// rows per request and the history is a few thousand rows. Re-fetched when
/// the timeline opens (it is a replay, live updates are not needed).
final statusEventsProvider = FutureProvider<List<StatusEvent>>((ref) async {
  ref.watch(authSessionProvider);
  final client = ref.watch(supabaseProvider);
  const page = 1000;
  final events = <StatusEvent>[];
  for (var from = 0; ; from += page) {
    final rows = await client
        .from('status_events')
        .select('object_type, object_id, status, changed_at')
        .order('changed_at')
        .order('id')
        .range(from, from + page - 1);
    events.addAll(rows.map(StatusEvent.fromJson));
    if (rows.length < page) break;
  }
  return events;
});

/// Manhole whose flow trace is shown on the map (null = off).
class TraceNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void show(String manholeId) => state = manholeId;
  void clear() => state = null;
}

final traceProvider = NotifierProvider<TraceNotifier, String?>(
  TraceNotifier.new,
);

enum TimelinePhase { moving, building, finale, done }

/// Replay position in a [TimelinePlan]: the camera flies to a part, then the
/// part's objects are built one by one, then the next part; finally the
/// camera zooms out to the whole network.
class TimelineState {
  final TimelinePlan plan;

  /// Index of the step being built (== steps.length when all are built).
  final int step;

  /// Build progress of [step], 0..1.
  final double stepProgress;
  final TimelinePhase phase;

  /// Time spent in a moving/finale phase (1x milliseconds).
  final double phaseMs;
  final bool playing;

  /// 1, 2, 4 or 8.
  final int speed;

  const TimelineState({
    required this.plan,
    this.step = 0,
    this.stepProgress = 0,
    this.phase = TimelinePhase.moving,
    this.phaseMs = 0,
    this.playing = false,
    this.speed = 2,
  });

  /// Camera flight between parts and the final zoom-out, at 1x.
  static const double moveMs = 1100;
  static const double finaleMs = 1800;

  int get total => plan.steps.length;

  bool get finished => step >= total;

  /// Real work date of the current step, if the history has one.
  DateTime? get at =>
      plan.steps.isEmpty ? null : plan.steps[math.min(step, total - 1)].at;

  BuildStep? get current => finished ? null : plan.steps[step];

  int get chunk => plan.chunks.isEmpty
      ? 0
      : plan.chunkOfStep[math.min(step, total - 1)];

  double get progress =>
      total == 0 ? 1 : ((step + stepProgress) / total).clamp(0.0, 1.0);

  TimelineState copyWith({
    int? step,
    double? stepProgress,
    TimelinePhase? phase,
    double? phaseMs,
    bool? playing,
    int? speed,
  }) => TimelineState(
    plan: plan,
    step: step ?? this.step,
    stepProgress: stepProgress ?? this.stepProgress,
    phase: phase ?? this.phase,
    phaseMs: phaseMs ?? this.phaseMs,
    playing: playing ?? this.playing,
    speed: speed ?? this.speed,
  );
}

/// Construction timeline replay (null = live map).
class TimelineNotifier extends Notifier<TimelineState?> {
  @override
  TimelineState? build() => null;

  void open(TimelinePlan plan) {
    state = TimelineState(plan: plan, playing: plan.steps.isNotEmpty);
  }

  void close() => state = null;

  /// Jumps to a position; the camera flies to that part first.
  void seek(double progress) {
    final s = state;
    if (s == null || s.total == 0) return;
    final step = (progress.clamp(0.0, 1.0) * s.total).floor();
    state = s.copyWith(
      step: math.min(step, s.total),
      stepProgress: 0,
      phase: step >= s.total ? TimelinePhase.done : TimelinePhase.moving,
      phaseMs: 0,
    );
  }

  void setPlaying(bool playing) {
    final s = state;
    if (s == null) return;
    if (playing && s.phase == TimelinePhase.done) {
      state = s.copyWith(
        step: 0,
        stepProgress: 0,
        phase: TimelinePhase.moving,
        phaseMs: 0,
        playing: true,
      );
    } else {
      state = s.copyWith(playing: playing);
    }
  }

  /// 1x → 2x → 4x → 8x → 1x.
  void cycleSpeed() {
    final s = state;
    if (s == null) return;
    state = s.copyWith(speed: s.speed >= 8 ? 1 : s.speed * 2);
  }

  /// Advances the replay by real time [dt].
  void advance(Duration dt) {
    final s = state;
    if (s == null || !s.playing) return;
    final ms = dt.inMicroseconds / 1000 * s.speed;
    switch (s.phase) {
      case TimelinePhase.moving:
        final t = s.phaseMs + ms;
        state = t >= TimelineState.moveMs
            ? s.copyWith(phase: TimelinePhase.building, phaseMs: 0)
            : s.copyWith(phaseMs: t);
      case TimelinePhase.building:
        final cur = s.current;
        if (cur == null) {
          state = s.copyWith(phase: TimelinePhase.finale, phaseMs: 0);
          return;
        }
        final p = s.stepProgress + ms / cur.durationMs;
        if (p < 1) {
          state = s.copyWith(stepProgress: p);
          return;
        }
        final next = s.step + 1;
        if (next >= s.total) {
          state = s.copyWith(
            step: next,
            stepProgress: 0,
            phase: TimelinePhase.finale,
            phaseMs: 0,
          );
        } else if (s.plan.chunkOfStep[next] != s.plan.chunkOfStep[s.step]) {
          state = s.copyWith(
            step: next,
            stepProgress: 0,
            phase: TimelinePhase.moving,
            phaseMs: 0,
          );
        } else {
          state = s.copyWith(step: next, stepProgress: 0);
        }
      case TimelinePhase.finale:
        final t = s.phaseMs + ms;
        state = t >= TimelineState.finaleMs
            ? s.copyWith(phase: TimelinePhase.done, playing: false)
            : s.copyWith(phaseMs: t);
      case TimelinePhase.done:
        state = s.copyWith(playing: false);
    }
  }
}

final timelineProvider = NotifierProvider<TimelineNotifier, TimelineState?>(
  TimelineNotifier.new,
);

/// Map look: Blueprint (default), Quyosh (high contrast for bright sun),
/// Tun (night map).
enum MapAppearance {
  blueprint('Blueprint', 'Xira xarita, tarmoq ajralib turadi'),
  sun('Quyosh', 'Yorqin kontrast, qalin chiziqlar — dalada'),
  night('Tun', 'Qorong\'i xarita, ko\'zni charchatmaydi');

  final String label;
  final String description;
  const MapAppearance(this.label, this.description);
}

class MapAppearanceNotifier extends Notifier<MapAppearance> {
  static const _key = 'map_appearance';

  @override
  MapAppearance build() {
    _load();
    return MapAppearance.blueprint;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_key);
      final saved = MapAppearance.values.where((v) => v.name == name);
      if (saved.isNotEmpty) state = saved.first;
    } catch (_) {}
  }

  Future<void> set(MapAppearance value) async {
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, value.name);
    } catch (_) {}
  }
}

final mapAppearanceProvider =
    NotifierProvider<MapAppearanceNotifier, MapAppearance>(
      MapAppearanceNotifier.new,
    );
