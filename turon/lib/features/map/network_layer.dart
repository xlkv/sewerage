import '../../data/models/manhole.dart';
import '../../data/models/pipe.dart';
import '../../data/models/work_status.dart';
import 'map_mode.dart';
import 'network_graph.dart';

/// Draws the sewer network on a map engine: MapKit on Android
/// ([MapObjectsLayerController]) or the Yandex JS API on Windows
/// ([DesktopNetworkLayer]). The map screen only talks to this interface.
abstract class NetworkLayer {
  /// False when the OS asks to reduce motion.
  abstract bool animationsEnabled;

  /// "Quyosh" appearance: thicker, higher-contrast pipes.
  abstract bool highContrast;

  bool get hasActiveAnimations;

  void sync({
    required Map<String, Manhole> allManholes,
    required Map<String, Pipe> allPipes,
    required Set<WorkStatus> activeStatuses,
    required Selection? selection,
    required MapMode mode,
    required double zoom,
    FlowTrace? trace,

    /// Manholes not to draw (still used for pipe coordinates).
    Set<String> hiddenManholeIds = const {},
  });

  /// Advances running animations (called ≤ 30 fps while
  /// [hasActiveAnimations]).
  void tick();

  void restylePipes();

  /// Dashed preview line while drawing a pipe (null clears it).
  void setRubberBand(
    ({double lat, double lng})? from,
    ({double lat, double lng})? to, {
    bool snapped = false,
  });

  /// Construction replay: grows pipe / pops manhole [id] to fraction [t];
  /// null finishes the current one.
  void setBuildProgress(String? id, {bool isPipe = false, double t = 1});
}
