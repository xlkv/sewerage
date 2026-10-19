import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/auth_repo.dart';
import 'network_graph.dart';

/// Full status history (small: one row per status change).
final statusEventsProvider = StreamProvider<List<StatusEvent>>((ref) {
  ref.watch(authSessionProvider);
  return ref
      .watch(supabaseProvider)
      .from('status_events')
      .stream(primaryKey: ['id'])
      .order('changed_at')
      .map((rows) => rows.map(StatusEvent.fromJson).toList());
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

  const TimelineState({
    required this.start,
    required this.end,
    required this.at,
    this.playing = false,
  });

  double get progress {
    final total = end.difference(start).inMinutes;
    if (total <= 0) return 1;
    return at.difference(start).inMinutes / total;
  }

  TimelineState copyWith({DateTime? at, bool? playing}) => TimelineState(
    start: start,
    end: end,
    at: at ?? this.at,
    playing: playing ?? this.playing,
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
    state = TimelineState(start: start, end: now, at: start, playing: true);
  }

  void close() => state = null;

  void seek(double progress) {
    final s = state;
    if (s == null) return;
    final total = s.end.difference(s.start).inMinutes;
    state = s.copyWith(
      at: s.start.add(Duration(minutes: (total * progress.clamp(0, 1)).round())),
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

  /// Advances playback; the whole range plays in ~8 seconds.
  void step(Duration dt) {
    final s = state;
    if (s == null || !s.playing) return;
    final total = s.end.difference(s.start);
    final next = s.at.add(total * (dt.inMilliseconds / 8000));
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
