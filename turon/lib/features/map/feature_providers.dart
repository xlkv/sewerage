import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/auth_repo.dart';
import '../../data/models/work_status.dart';
import 'network_graph.dart';

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

class TimelineState {
  final DateTime start;
  final DateTime end;
  final DateTime at;
  final bool playing;

  /// Real time the whole range takes at 1x.
  final Duration playback;

  /// 1, 2 or 4.
  final int speed;

  const TimelineState({
    required this.start,
    required this.end,
    required this.at,
    this.playing = false,
    this.playback = const Duration(seconds: 30),
    this.speed = 1,
  });

  double get progress {
    final total = end.difference(start).inMinutes;
    if (total <= 0) return 1;
    return at.difference(start).inMinutes / total;
  }

  TimelineState copyWith({DateTime? at, bool? playing, int? speed}) =>
      TimelineState(
        start: start,
        end: end,
        at: at ?? this.at,
        playing: playing ?? this.playing,
        playback: playback,
        speed: speed ?? this.speed,
      );
}

/// Construction timeline replay (null = live map).
class TimelineNotifier extends Notifier<TimelineState?> {
  @override
  TimelineState? build() => null;

  void open(List<StatusEvent> events) {
    final now = DateTime.now();
    final first = events.isEmpty
        ? now.subtract(const Duration(days: 1))
        : events
              .map((e) => e.changedAt)
              .reduce((a, b) => a.isBefore(b) ? a : b);
    final start = DateTime(first.year, first.month, first.day);
    // ~0.35 s per started object so every pipe is seen being built.
    final started = events
        .where((e) => e.status == WorkStatus.inProgress)
        .length;
    final ms = (started * 350).clamp(20000, 240000);
    state = TimelineState(
      start: start,
      end: now,
      at: start,
      playing: true,
      playback: Duration(milliseconds: ms),
    );
  }

  /// 1x → 2x → 4x → 1x.
  void cycleSpeed() {
    final s = state;
    if (s == null) return;
    state = s.copyWith(speed: s.speed >= 4 ? 1 : s.speed * 2);
  }

  void close() => state = null;

  void seek(double progress) {
    final s = state;
    if (s == null) return;
    final total = s.end.difference(s.start).inMinutes;
    state = s.copyWith(
      at: s.start.add(
        Duration(minutes: (total * progress.clamp(0, 1)).round()),
      ),
    );
  }

  void setPlaying(bool playing) {
    final s = state;
    if (s == null) return;
    if (playing && s.progress >= 1) {
      state = s.copyWith(at: s.start, playing: true);
    } else {
      state = s.copyWith(playing: playing);
    }
  }

  /// Advances playback.
  void step(Duration dt) {
    final s = state;
    if (s == null || !s.playing) return;
    final total = s.end.difference(s.start);
    final next = s.at.add(
      total * (dt.inMilliseconds * s.speed / s.playback.inMilliseconds),
    );
    if (!next.isBefore(s.end)) {
      state = s.copyWith(at: s.end, playing: false);
    } else {
      state = s.copyWith(at: next);
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
