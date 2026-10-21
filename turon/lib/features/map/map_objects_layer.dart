import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'network_graph.dart';
import 'package:yandex_maps_mapkit_lite/image.dart' as ymk_image;
import 'package:yandex_maps_mapkit_lite/mapkit.dart' as ymk;

import '../../core/geo_utils.dart';
import '../../core/theme.dart';
import '../../data/models/manhole.dart';
import '../../data/models/pipe.dart';
import '../../data/models/work_status.dart';
import 'map_mode.dart';

/// Pure diff result for map object collections.
class ObjectIdDiff {
  final Set<String> toRemove;
  final Set<String> toAdd;
  final Set<String> toUpdate;

  const ObjectIdDiff({
    required this.toRemove,
    required this.toAdd,
    required this.toUpdate,
  });

  static ObjectIdDiff compute(
    Set<String> existingIds,
    Set<String> nextIds,
  ) {
    return ObjectIdDiff(
      toRemove: existingIds.difference(nextIds),
      toAdd: nextIds.difference(existingIds),
      toUpdate: existingIds.intersection(nextIds),
    );
  }
}

/// Cache key for manhole marker bitmaps: `(status, code, selected, zoomBucket)`.
class ManholeMarkerCacheKey {
  final WorkStatus status;
  final String code;
  final bool selected;
  final String zoomBucket;

  const ManholeMarkerCacheKey({
    required this.status,
    required this.code,
    required this.selected,
    required this.zoomBucket,
  });

  static String bucketForZoom(double zoom) =>
      zoom < MapObjectsLayer.codeMinZoom ? 'dot' : 'full';

  String get id =>
      'mh_${status.name}_${selected ? 'sel' : 'norm'}_${zoomBucket}_$code';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ManholeMarkerCacheKey &&
          other.status == status &&
          other.code == code &&
          other.selected == selected &&
          other.zoomBucket == zoomBucket;

  @override
  int get hashCode => Object.hash(status, code, selected, zoomBucket);
}

/// Pure filtering and geometry helper functions for map objects (LLD 4.6 & Step 4).
class MapObjectsLayer {
  const MapObjectsLayer._();

  static const double codeMinZoom = 14.0;
  static const double labelMinZoom = 14.0;

  static const double pipeStrokeWidthDp = 5.0;
  static const double pipeSelectedStrokeWidthDp = 8.0;

  /// Zoom from which pipe length/diameter labels are shown.
  static const double pipeLabelMinZoom = 16.0;

  static const Color traceDownColor = AppColors.brand;
  static const Color traceUpColor = Color(0xFF6366F1);

  /// Max objects animated at once (flow dashes, pulse halos) — DESIGN §2.
  static const int maxAnimatedObjects = 40;

  /// Pipe core width by diameter (DESIGN §2).
  static double pipeWidthForDiameter(int diameterMm) {
    if (diameterMm <= 110) return 4.0;
    if (diameterMm <= 200) return 5.0;
    if (diameterMm <= 315) return 6.0;
    return 8.0;
  }

  /// Filters manholes by active status set.
  static List<Manhole> filterManholes(
    Map<String, Manhole> manholes,
    Set<WorkStatus> activeStatuses, {
    String? forceIncludeManholeId,
  }) {
    return manholes.values
        .where(
          (m) =>
              activeStatuses.contains(m.status) ||
              (forceIncludeManholeId != null && m.id == forceIncludeManholeId),
        )
        .toList();
  }

  /// Filters pipes by active status set.
  /// Per LLD 4.6 / step 2 spec: if a pipe passes the status filter, it is drawn
  /// even if its endpoint manholes are filtered out, as long as the endpoint
  /// manholes exist in [allManholes] so coordinates are known.
  static List<Pipe> filterPipes(
    Map<String, Pipe> pipes,
    Set<WorkStatus> activeStatuses, {
    Map<String, Manhole>? allManholes,
  }) {
    return pipes.values.where((p) {
      if (!activeStatuses.contains(p.status)) return false;
      if (allManholes != null) {
        return allManholes.containsKey(p.fromManholeId) &&
            allManholes.containsKey(p.toManholeId);
      }
      return true;
    }).toList();
  }

  static bool shouldShowCodeLabel(double zoom) => zoom >= codeMinZoom;

  static String zoomBucket(double zoom) =>
      ManholeMarkerCacheKey.bucketForZoom(zoom);

  /// Returns the geographic anchor point (lat, lng) for the active [selection]:
  /// - [ManholeSelection]: manhole's `(lat, lng)`
  /// - [PipeSelection]: midpoint `(lat, lng)` between `fromManhole` and `toManhole`
  static ({double lat, double lng})? selectionAnchorPoint({
    required Selection? selection,
    required Map<String, Manhole> allManholes,
    required Map<String, Pipe> allPipes,
  }) {
    if (selection == null) return null;
    switch (selection) {
      case ManholeSelection(:final id):
        final m = allManholes[id];
        if (m == null) return null;
        return (lat: m.lat, lng: m.lng);
      case PipeSelection(:final id):
        final p = allPipes[id];
        if (p == null) return null;
        final from = allManholes[p.fromManholeId];
        final to = allManholes[p.toManholeId];
        if (from == null || to == null) return null;
        final mid = GeoUtils.alongPolyline([
          (lat: from.lat, lng: from.lng),
          for (final b in p.path) (lat: b[0], lng: b[1]),
          (lat: to.lat, lng: to.lng),
        ], 0.5);
        return (lat: mid.lat, lng: mid.lng);
    }
  }
}

class _ManholeSnapshot {
  final double lat;
  final double lng;
  final WorkStatus status;
  final String code;
  final String zoomBucket;
  final bool isSelected;
  final bool isDraggable;

  const _ManholeSnapshot({
    required this.lat,
    required this.lng,
    required this.status,
    required this.code,
    required this.zoomBucket,
    required this.isSelected,
    required this.isDraggable,
  });

  ManholeMarkerCacheKey get cacheKey => ManholeMarkerCacheKey(
    status: status,
    // Dots carry no label, so all dots of a status share one bitmap.
    code: zoomBucket == 'dot' ? '' : code,
    selected: isSelected,
    zoomBucket: zoomBucket,
  );

  // Identity only: look changes (status, selection, zoom) are applied in
  // place by the update pass instead of removing and re-adding the object.
  String diffKey(String id) => id;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ManholeSnapshot &&
          other.lat == lat &&
          other.lng == lng &&
          other.status == status &&
          other.code == code &&
          other.zoomBucket == zoomBucket &&
          other.isSelected == isSelected &&
          other.isDraggable == isDraggable;

  @override
  int get hashCode => Object.hash(
    lat,
    lng,
    status,
    code,
    zoomBucket,
    isSelected,
    isDraggable,
  );
}

class _PipeSnapshot {
  final double fromLat;
  final double fromLng;
  final double toLat;
  final double toLng;
  final WorkStatus status;
  final bool isSelected;
  final double widthDp;

  /// Interior bend points [[lat, lng], ...] (curved pipes from KML).
  final List<List<double>> bends;

  const _PipeSnapshot({
    required this.fromLat,
    required this.fromLng,
    required this.toLat,
    required this.toLng,
    required this.status,
    required this.isSelected,
    required this.widthDp,
    this.bends = const [],
  });

  String get _bendsKey => bends.map((b) => '${b[0]},${b[1]}').join(';');

  /// from → bends → to.
  List<({double lat, double lng})> get coords => [
    (lat: fromLat, lng: fromLng),
    for (final b in bends) (lat: b[0], lng: b[1]),
    (lat: toLat, lng: toLng),
  ];

  ymk.Polyline get polyline => ymk.Polyline([
    for (final c in coords) ymk.Point(latitude: c.lat, longitude: c.lng),
  ]);

  /// Point halfway along the pipe and the flow bearing there.
  ({double lat, double lng, double bearing}) get middle =>
      GeoUtils.alongPolyline(coords, 0.5);

  /// The first [fraction] of the pipe (draw-on animation).
  ymk.Polyline partial(double fraction) {
    final pts = coords;
    final lengths = <double>[];
    var total = 0.0;
    for (var i = 0; i < pts.length - 1; i++) {
      final d = GeoUtils.haversineMeters(
        pts[i].lat,
        pts[i].lng,
        pts[i + 1].lat,
        pts[i + 1].lng,
      );
      lengths.add(d);
      total += d;
    }
    final target = total * fraction.clamp(0.0, 1.0);
    final out = [ymk.Point(latitude: pts[0].lat, longitude: pts[0].lng)];
    var acc = 0.0;
    for (var i = 0; i < lengths.length; i++) {
      if (acc + lengths[i] >= target) {
        final t = lengths[i] == 0 ? 0.0 : (target - acc) / lengths[i];
        out.add(
          ymk.Point(
            latitude: pts[i].lat + (pts[i + 1].lat - pts[i].lat) * t,
            longitude: pts[i].lng + (pts[i + 1].lng - pts[i].lng) * t,
          ),
        );
        return ymk.Polyline(out);
      }
      acc += lengths[i];
      out.add(ymk.Point(latitude: pts[i + 1].lat, longitude: pts[i + 1].lng));
    }
    return ymk.Polyline(out);
  }

  String diffKey(String id) => id;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _PipeSnapshot &&
          other.fromLat == fromLat &&
          other.fromLng == fromLng &&
          other.toLat == toLat &&
          other.toLng == toLng &&
          other.status == status &&
          other.isSelected == isSelected &&
          other.widthDp == widthDp &&
          other._bendsKey == _bendsKey;

  @override
  int get hashCode => Object.hash(
    fromLat,
    fromLng,
    toLat,
    toLng,
    status,
    isSelected,
    widthDp,
    _bendsKey,
  );
}

class _TapListenerImpl implements ymk.MapObjectTapListener {
  final void Function(ymk.Point point) onTap;

  _TapListenerImpl(this.onTap);

  @override
  bool onMapObjectTap(ymk.MapObject mapObject, ymk.Point point) {
    onTap(point);
    return true;
  }
}

class _DragListenerImpl implements ymk.MapObjectDragListener {
  final void Function(ymk.Point point) onDrag;

  _DragListenerImpl(this.onDrag);

  @override
  void onMapObjectDragStart(ymk.MapObject mapObject) {}

  @override
  void onMapObjectDrag(ymk.MapObject mapObject, ymk.Point point) {
    onDrag(point);
  }

  @override
  void onMapObjectDragEnd(ymk.MapObject mapObject) {}
}

/// Manages diff-updated Yandex MapKit collections for pipes, direction arrows, and manholes.
class MapObjectsLayerController {
  final ymk.MapObjectCollection rootCollection;
  final void Function(String manholeId) onManholeTap;
  final void Function(String pipeId) onPipeTap;
  final void Function(double lat, double lng) onManholeMoved;

  late final ymk.MapObjectCollection _pipesCollection;
  late final ymk.MapObjectCollection _arrowsCollection;
  late final ymk.MapObjectCollection _manholesCollection;

  final Map<String, ymk.PlacemarkMapObject> _manholePlacemarks = {};
  final Map<String, _ManholeSnapshot> _manholeSnapshots = {};
  final Map<String, ymk.MapObjectTapListener> _manholeTapListeners = {};
  final Map<String, ymk.MapObjectDragListener> _manholeDragListeners = {};

  final Map<String, ymk.PolylineMapObject> _pipePolylines = {};
  final Map<String, ymk.PlacemarkMapObject> _pipeArrows = {};
  final Map<String, _PipeSnapshot> _pipeSnapshots = {};
  final Map<String, ymk.MapObjectTapListener> _pipeTapListeners = {};
  final Map<String, ymk.MapObjectTapListener> _arrowTapListeners = {};
  String? _lastLoggedBucket;

  // Animations (DESIGN §2): one external ticker calls [tick].
  late final ymk.MapObjectCollection _flowCollection;
  late final ymk.MapObjectCollection _haloCollection;
  final Map<String, ymk.PolylineMapObject> _flowPolylines = {};
  final Map<String, ymk.MapObjectTapListener> _flowTapListeners = {};
  final Map<String, ymk.PlacemarkMapObject> _halos = {};
  final Map<String, int> _dropInStartMs = {};
  final Map<String, int> _drawOnStartMs = {};
  final Set<String> _knownManholeIds = {};
  final Set<String> _knownPipeIds = {};
  final Stopwatch _clock = Stopwatch()..start();
  bool _initialSyncDone = false;

  /// False when the OS asks to reduce motion.
  bool animationsEnabled = true;

  /// "Quyosh" appearance: thicker, higher-contrast pipes.
  bool highContrast = false;

  late final ymk.MapObjectCollection _traceCollection;
  late final ymk.MapObjectCollection _labelsCollection;
  late final ymk.MapObjectCollection _rubberCollection;
  final Map<String, ymk.PolylineMapObject> _traceLines = {};
  final Map<String, String> _traceKeys = {};
  final Map<String, ymk.PlacemarkMapObject> _pipeLabels = {};
  final Map<String, String> _pipeLabelTexts = {};
  final Map<String, Pipe> _pipesById = {};
  ymk.PolylineMapObject? _rubberLine;
  FlowTrace? _trace;
  bool _showLabels = false;

  bool get hasActiveAnimations =>
      animationsEnabled &&
      (_flowPolylines.isNotEmpty ||
          _halos.isNotEmpty ||
          _dropInStartMs.isNotEmpty ||
          _drawOnStartMs.isNotEmpty);

  static final Map<ManholeMarkerCacheKey, ymk_image.ImageProvider>
  _manholeIconCache = {};
  static final Map<String, ymk_image.ImageProvider> _arrowIconCache = {};

  @visibleForTesting
  static Map<ManholeMarkerCacheKey, ymk_image.ImageProvider>
  get manholeIconCacheForTest => _manholeIconCache;

  MapObjectsLayerController({
    required this.rootCollection,
    required this.onManholeTap,
    required this.onPipeTap,
    required this.onManholeMoved,
  }) {
    // Sub-collections ordered back-to-front:
    // trace glow -> pipes -> flow dashes -> arrows -> rubber band ->
    // labels -> pulse halos -> manholes.
    _traceCollection = rootCollection.addCollection();
    _pipesCollection = rootCollection.addCollection();
    _flowCollection = rootCollection.addCollection();
    _arrowsCollection = rootCollection.addCollection();
    _rubberCollection = rootCollection.addCollection();
    _labelsCollection = rootCollection.addCollection();
    _haloCollection = rootCollection.addCollection();
    _manholesCollection = rootCollection.addCollection();
  }

  /// Synchronizes map objects by diffing against the previous snapshot.
  void sync({
    required Map<String, Manhole> allManholes,
    required Map<String, Pipe> allPipes,
    required Set<WorkStatus> activeStatuses,
    required Selection? selection,
    required MapMode mode,
    required double zoom,
    FlowTrace? trace,
  }) {
    _trace = trace;
    _showLabels = zoom >= MapObjectsLayer.pipeLabelMinZoom;
    _pipesById
      ..clear()
      ..addAll(allPipes);
    final movingManholeId = mode is MoveManholeMode ? mode.manholeId : null;

    final visibleManholes = MapObjectsLayer.filterManholes(
      allManholes,
      activeStatuses,
      forceIncludeManholeId: movingManholeId,
    );
    final visibleManholeMap = {for (final m in visibleManholes) m.id: m};

    final visiblePipes = MapObjectsLayer.filterPipes(
      allPipes,
      activeStatuses,
      allManholes: allManholes,
    );
    final visiblePipeMap = {for (final p in visiblePipes) p.id: p};

    _syncManholes(
      visibleManholeMap: visibleManholeMap,
      selection: selection,
      mode: mode,
      zoom: zoom,
    );

    _syncPipes(
      allManholes: allManholes,
      visiblePipeMap: visiblePipeMap,
      selection: selection,
      mode: mode,
    );

    _syncTrace();
    _syncLabels();
    _syncFlows();
    _syncHalos();
    _initialSyncDone = true;
  }

  void _syncManholes({
    required Map<String, Manhole> visibleManholeMap,
    required Selection? selection,
    required MapMode mode,
    required double zoom,
  }) {
    final bucket = MapObjectsLayer.zoomBucket(zoom);
    if (visibleManholeMap.isNotEmpty && _lastLoggedBucket != bucket) {
      _lastLoggedBucket = bucket;
      final sampleCode = visibleManholeMap.values.first.code;
      debugPrint(
        'TuronMapKit: manhole marker variant=$bucket (zoom=${zoom.toStringAsFixed(1)}, circleDp=${bucket == 'dot' ? 14 : 40}, sampleCode=$sampleCode)',
      );
    }

    final nextSnapshots = <String, _ManholeSnapshot>{};
    for (final entry in visibleManholeMap.entries) {
      final id = entry.key;
      final manhole = entry.value;

      final isMovingThis =
          mode is MoveManholeMode && mode.manholeId == manhole.id;
      final effectiveLat = isMovingThis ? mode.newLat : manhole.lat;
      final effectiveLng = isMovingThis ? mode.newLng : manhole.lng;

      final isSelected =
          (selection is ManholeSelection && selection.id == manhole.id) ||
          (mode is AddPipeMode &&
              (mode.fromManholeId == manhole.id ||
                  mode.toManholeId == manhole.id)) ||
          isMovingThis;

      nextSnapshots[id] = _ManholeSnapshot(
        lat: effectiveLat,
        lng: effectiveLng,
        status: manhole.status,
        code: manhole.code,
        zoomBucket: bucket,
        isSelected: isSelected,
        isDraggable: isMovingThis,
      );
    }

    final existingDiffKeys = {
      for (final e in _manholeSnapshots.entries) e.value.diffKey(e.key),
    };
    final nextDiffKeys = {
      for (final e in nextSnapshots.entries) e.value.diffKey(e.key),
    };

    final diff = ObjectIdDiff.compute(existingDiffKeys, nextDiffKeys);

    for (final diffKey in diff.toRemove) {
      final id = diffKey.split('|').first;
      final placemark = _manholePlacemarks.remove(id);
      final tapListener = _manholeTapListeners.remove(id);
      _manholeDragListeners.remove(id);
      _manholeSnapshots.remove(id);
      if (placemark != null && placemark.isValid()) {
        if (tapListener != null) {
          placemark.removeTapListener(tapListener);
        }
        _manholesCollection.remove(placemark);
      }
    }

    for (final diffKey in diff.toUpdate) {
      final id = diffKey.split('|').first;
      final snapshot = nextSnapshots[id];
      final prevSnapshot = _manholeSnapshots[id];
      final placemark = _manholePlacemarks[id];
      if (snapshot == null) continue;
      if (placemark == null || !placemark.isValid()) {
        diff.toAdd.add(diffKey);
        continue;
      }
      if (prevSnapshot == snapshot) continue;

      if (prevSnapshot == null ||
          prevSnapshot.lat != snapshot.lat ||
          prevSnapshot.lng != snapshot.lng) {
        placemark.geometry = ymk.Point(
          latitude: snapshot.lat,
          longitude: snapshot.lng,
        );
      }
      if (prevSnapshot == null ||
          prevSnapshot.isDraggable != snapshot.isDraggable) {
        placemark.draggable = snapshot.isDraggable;
      }
      // Selection, status, code or zoom bucket changed: redraw the icon,
      // otherwise the old (e.g. selected) bitmap stays on the map.
      if (prevSnapshot == null || prevSnapshot.cacheKey != snapshot.cacheKey) {
        placemark.setIconWithStyle(
          manholeIconProvider(snapshot.cacheKey),
          ymk.IconStyle(
            scale: 1.0,
            zIndex: snapshot.isSelected ? 20.0 : 10.0,
          ),
        );
      }
      _manholeSnapshots[id] = snapshot;
    }

    for (final diffKey in diff.toAdd) {
      final id = diffKey.split('|').first;
      final snapshot = nextSnapshots[id];
      if (snapshot == null) continue;

      final placemark = _manholesCollection.addPlacemark();
      _manholePlacemarks[id] = placemark;

      final tapListener = _TapListenerImpl((_) => onManholeTap(id));
      _manholeTapListeners[id] = tapListener;
      placemark.addTapListener(tapListener);

      final dragListener = _DragListenerImpl((point) {
        onManholeMoved(point.latitude, point.longitude);
      });
      _manholeDragListeners[id] = dragListener;
      placemark.setDragListener(dragListener);

      placemark.geometry = ymk.Point(
        latitude: snapshot.lat,
        longitude: snapshot.lng,
      );
      final isNew = _initialSyncDone && !_knownManholeIds.contains(id);
      // Cap concurrent drop-ins (timeline replay can add hundreds at once).
      final dropIn =
          isNew &&
          animationsEnabled &&
          _dropInStartMs.length < MapObjectsLayer.maxAnimatedObjects;
      placemark.setIconWithStyle(
        manholeIconProvider(snapshot.cacheKey),
        ymk.IconStyle(
          scale: dropIn ? 0.01 : 1.0,
          zIndex: snapshot.isSelected ? 20.0 : 10.0,
        ),
      );
      if (dropIn) _dropInStartMs[id] = _clock.elapsedMilliseconds;
      placemark.draggable = snapshot.isDraggable;

      _manholeSnapshots[id] = snapshot;
    }
    _knownManholeIds
      ..removeWhere((id) => !nextSnapshots.containsKey(id))
      ..addAll(nextSnapshots.keys);
    _dropInStartMs.removeWhere((id, _) => !nextSnapshots.containsKey(id));
  }

  void _syncPipes({
    required Map<String, Manhole> allManholes,
    required Map<String, Pipe> visiblePipeMap,
    required Selection? selection,
    required MapMode mode,
  }) {
    final nextSnapshots = <String, _PipeSnapshot>{};
    for (final entry in visiblePipeMap.entries) {
      final id = entry.key;
      final pipe = entry.value;
      final fromManhole = allManholes[pipe.fromManholeId];
      final toManhole = allManholes[pipe.toManholeId];
      if (fromManhole == null || toManhole == null) continue;

      final fromLat =
          (mode is MoveManholeMode && mode.manholeId == fromManhole.id)
          ? mode.newLat
          : fromManhole.lat;
      final fromLng =
          (mode is MoveManholeMode && mode.manholeId == fromManhole.id)
          ? mode.newLng
          : fromManhole.lng;
      final toLat = (mode is MoveManholeMode && mode.manholeId == toManhole.id)
          ? mode.newLat
          : toManhole.lat;
      final toLng = (mode is MoveManholeMode && mode.manholeId == toManhole.id)
          ? mode.newLng
          : toManhole.lng;

      final isSelected = selection is PipeSelection && selection.id == pipe.id;

      nextSnapshots[id] = _PipeSnapshot(
        fromLat: fromLat,
        fromLng: fromLng,
        toLat: toLat,
        toLng: toLng,
        status: pipe.status,
        isSelected: isSelected,
        widthDp: MapObjectsLayer.pipeWidthForDiameter(pipe.diameterMm),
        bends: pipe.path,
      );
    }

    final existingDiffKeys = {
      for (final e in _pipeSnapshots.entries) e.value.diffKey(e.key),
    };
    final nextDiffKeys = {
      for (final e in nextSnapshots.entries) e.value.diffKey(e.key),
    };

    final diff = ObjectIdDiff.compute(existingDiffKeys, nextDiffKeys);

    for (final diffKey in diff.toRemove) {
      final id = diffKey.split('|').first;
      final polyline = _pipePolylines.remove(id);
      final pipeTap = _pipeTapListeners.remove(id);
      if (polyline != null && polyline.isValid()) {
        if (pipeTap != null) {
          polyline.removeTapListener(pipeTap);
        }
        _pipesCollection.remove(polyline);
      }

      final arrow = _pipeArrows.remove(id);
      final arrowTap = _arrowTapListeners.remove(id);
      if (arrow != null && arrow.isValid()) {
        if (arrowTap != null) {
          arrow.removeTapListener(arrowTap);
        }
        _arrowsCollection.remove(arrow);
      }

      _pipeSnapshots.remove(id);
    }

    for (final diffKey in diff.toUpdate) {
      final id = diffKey.split('|').first;
      final snapshot = nextSnapshots[id];
      final prevSnapshot = _pipeSnapshots[id];
      final polyline = _pipePolylines[id];
      final arrow = _pipeArrows[id];
      if (snapshot == null) continue;
      if (polyline == null ||
          !polyline.isValid() ||
          arrow == null ||
          !arrow.isValid()) {
        diff.toAdd.add(diffKey);
        continue;
      }
      if (prevSnapshot == snapshot) continue;

      if (prevSnapshot == null ||
          prevSnapshot.fromLat != snapshot.fromLat ||
          prevSnapshot.fromLng != snapshot.fromLng ||
          prevSnapshot.toLat != snapshot.toLat ||
          prevSnapshot.toLng != snapshot.toLng ||
          prevSnapshot._bendsKey != snapshot._bendsKey) {
        if (!_drawOnStartMs.containsKey(id)) {
          polyline.geometry = snapshot.polyline;
        }
        final mid = snapshot.middle;
        arrow.geometry = ymk.Point(latitude: mid.lat, longitude: mid.lng);
        arrow.direction = mid.bearing;
      }
      if (prevSnapshot == null ||
          prevSnapshot.status != snapshot.status ||
          prevSnapshot.isSelected != snapshot.isSelected ||
          prevSnapshot.widthDp != snapshot.widthDp) {
        _applyPipeStyle(polyline, snapshot);
        arrow.setIconWithStyle(
          _arrowIconProvider(snapshot.status, snapshot.isSelected),
          ymk.IconStyle(
            rotationType: ymk.RotationType.Rotate,
            zIndex: snapshot.isSelected ? 8.0 : 3.0,
            flat: true,
          ),
        );
      }
      _pipeSnapshots[id] = snapshot;
    }

    for (final diffKey in diff.toAdd) {
      final id = diffKey.split('|').first;
      final snapshot = nextSnapshots[id];
      if (snapshot == null) continue;

      final polyline = _pipesCollection.addPolylineWithGeometry(
        snapshot.polyline,
      );
      _pipePolylines[id] = polyline;

      final tapListener = _TapListenerImpl((_) => onPipeTap(id));
      _pipeTapListeners[id] = tapListener;
      polyline.addTapListener(tapListener);

      _applyPipeStyle(polyline, snapshot);
      final isNewPipe = _initialSyncDone && !_knownPipeIds.contains(id);
      if (isNewPipe &&
          animationsEnabled &&
          _drawOnStartMs.length < MapObjectsLayer.maxAnimatedObjects) {
        _drawOnStartMs[id] = _clock.elapsedMilliseconds;
        polyline.geometry = snapshot.partial(0);
      }

      final mid = snapshot.middle;
      final bearing = mid.bearing;

      final arrow = _arrowsCollection.addPlacemark();
      _pipeArrows[id] = arrow;

      final arrowTap = _TapListenerImpl((_) => onPipeTap(id));
      _arrowTapListeners[id] = arrowTap;
      arrow.addTapListener(arrowTap);

      arrow.geometry = ymk.Point(latitude: mid.lat, longitude: mid.lng);
      arrow.direction = bearing;
      arrow.setIconWithStyle(
        _arrowIconProvider(snapshot.status, snapshot.isSelected),
        ymk.IconStyle(
          rotationType: ymk.RotationType.Rotate,
          zIndex: snapshot.isSelected ? 8.0 : 3.0,
          flat: true,
        ),
      );
      if (_drawOnStartMs.containsKey(id)) arrow.visible = false;

      _pipeSnapshots[id] = snapshot;
    }
    _knownPipeIds
      ..removeWhere((id) => !nextSnapshots.containsKey(id))
      ..addAll(nextSnapshots.keys);
    _drawOnStartMs.removeWhere((id, _) => !nextSnapshots.containsKey(id));
  }

  /// Casing (white outline) + status core; planned is dashed; selected glows.
  void _applyPipeStyle(
    ymk.PolylineMapObject polyline,
    _PipeSnapshot snapshot,
  ) {
    polyline.setStrokeColor(AppColors.forStatus(snapshot.status));
    final planned = snapshot.status == WorkStatus.planned;
    polyline.style = ymk.LineStyle(
      strokeWidth:
          snapshot.widthDp +
          (snapshot.isSelected ? 2.0 : 0.0) +
          (highContrast ? 2.0 : 0.0),
      outlineWidth: snapshot.isSelected ? 3.0 : (highContrast ? 2.5 : 2.0),
      outlineColor: snapshot.isSelected
          ? AppColors.brand.withValues(alpha: 0.45)
          : Colors.white,
      dashLength: planned ? 10.0 : 0.0,
      gapLength: planned ? 6.0 : 0.0,
    );
    polyline.zIndex = snapshot.isSelected ? 5.0 : 1.0;
  }

  static ymk.LineStyle _flowStyle(_PipeSnapshot snapshot, double offset) =>
      ymk.LineStyle(
        strokeWidth: math.max(2.0, snapshot.widthDp * 0.45),
        dashLength: 5.0,
        gapLength: 11.0,
        dashOffset: offset,
      );

  static const double _flowPeriod = 16.0; // dashLength + gapLength

  /// Flow dashes over in-progress and selected pipes (selected first).
  void _syncFlows() {
    final wanted = <String>[];
    if (animationsEnabled) {
      final traced = {
        ...?_trace?.downstreamPipes,
        ...?_trace?.upstreamPipes,
      };
      int rank(MapEntry<String, _PipeSnapshot> e) =>
          (e.value.isSelected ? 2 : 0) + (traced.contains(e.key) ? 1 : 0);
      final candidates =
          _pipeSnapshots.entries
              .where(
                (e) =>
                    e.value.isSelected ||
                    traced.contains(e.key) ||
                    e.value.status == WorkStatus.inProgress,
              )
              .toList()
            ..sort((a, b) => rank(b) - rank(a));
      wanted.addAll(
        candidates.take(MapObjectsLayer.maxAnimatedObjects).map((e) => e.key),
      );
    }

    for (final id in _flowPolylines.keys.toList()) {
      if (wanted.contains(id)) continue;
      final flow = _flowPolylines.remove(id);
      final tap = _flowTapListeners.remove(id);
      if (flow != null && flow.isValid()) {
        if (tap != null) flow.removeTapListener(tap);
        _flowCollection.remove(flow);
      }
    }

    for (final id in wanted) {
      final snapshot = _pipeSnapshots[id]!;
      final geometry = snapshot.polyline;
      var flow = _flowPolylines[id];
      if (flow == null || !flow.isValid()) {
        flow = _flowCollection.addPolylineWithGeometry(geometry);
        flow.setStrokeColor(Colors.white.withValues(alpha: 0.9));
        final tap = _TapListenerImpl((_) => onPipeTap(id));
        _flowTapListeners[id] = tap;
        flow.addTapListener(tap);
        _flowPolylines[id] = flow;
      } else if (!_drawOnStartMs.containsKey(id)) {
        flow.geometry = geometry;
      }
      flow.visible = !_drawOnStartMs.containsKey(id);
      flow.style = _flowStyle(snapshot, 0);
      flow.zIndex = snapshot.isSelected ? 6.0 : 2.0;
    }
  }

  /// Pulse halos under in-progress manholes.
  void _syncHalos() {
    final wanted = <String>[];
    if (animationsEnabled) {
      wanted.addAll(
        _manholeSnapshots.entries
            .where((e) => e.value.status == WorkStatus.inProgress)
            .take(MapObjectsLayer.maxAnimatedObjects)
            .map((e) => e.key),
      );
    }
    for (final id in _halos.keys.toList()) {
      if (wanted.contains(id)) continue;
      final halo = _halos.remove(id);
      if (halo != null && halo.isValid()) _haloCollection.remove(halo);
    }
    for (final id in wanted) {
      final snapshot = _manholeSnapshots[id]!;
      final point = ymk.Point(latitude: snapshot.lat, longitude: snapshot.lng);
      var halo = _halos[id];
      if (halo == null || !halo.isValid()) {
        halo = _haloCollection.addPlacemark();
        halo.setIconWithStyle(
          _haloIconProvider(snapshot.zoomBucket),
          const ymk.IconStyle(scale: 1.0, zIndex: 9.0),
        );
        _halos[id] = halo;
      }
      halo.geometry = point;
    }
  }

  /// Wide translucent glow under traced pipes: teal downstream, indigo
  /// upstream. Flow dashes on them come from [_syncFlows].
  void _syncTrace() {
    final wanted = <String, Color>{};
    final t = _trace;
    if (t != null) {
      for (final id in t.upstreamPipes) {
        wanted[id] = MapObjectsLayer.traceUpColor;
      }
      for (final id in t.downstreamPipes) {
        wanted[id] = MapObjectsLayer.traceDownColor;
      }
    }
    for (final id in _traceLines.keys.toList()) {
      final snapshot = _pipeSnapshots[id];
      if (wanted.containsKey(id) && snapshot != null) continue;
      final line = _traceLines.remove(id);
      _traceKeys.remove(id);
      if (line != null && line.isValid()) _traceCollection.remove(line);
    }
    for (final entry in wanted.entries) {
      final snapshot = _pipeSnapshots[entry.key];
      if (snapshot == null) continue;
      final key =
          '${entry.value.toARGB32()}|${snapshot.fromLat},${snapshot.fromLng},'
          '${snapshot.toLat},${snapshot.toLng}|${snapshot.widthDp}|'
          '${snapshot._bendsKey}';
      if (_traceKeys[entry.key] == key) continue;
      var line = _traceLines[entry.key];
      final geometry = snapshot.polyline;
      if (line == null || !line.isValid()) {
        line = _traceCollection.addPolylineWithGeometry(geometry);
        _traceLines[entry.key] = line;
      } else {
        line.geometry = geometry;
      }
      line.setStrokeColor(entry.value.withValues(alpha: 0.32));
      line.style = ymk.LineStyle(strokeWidth: snapshot.widthDp + 12);
      _traceKeys[entry.key] = key;
    }
  }

  /// "48 m · Ø315" pills under pipe midpoints at close zoom.
  void _syncLabels() {
    final wanted = <String, String>{};
    if (_showLabels) {
      for (final entry in _pipeSnapshots.entries) {
        final pipe = _pipesById[entry.key];
        if (pipe == null) continue;
        wanted[entry.key] =
            '${GeoUtils.formatLength(pipe.lengthM)} · Ø${pipe.diameterMm}';
      }
    }
    for (final id in _pipeLabels.keys.toList()) {
      if (wanted.containsKey(id)) continue;
      final label = _pipeLabels.remove(id);
      _pipeLabelTexts.remove(id);
      if (label != null && label.isValid()) _labelsCollection.remove(label);
    }
    for (final entry in wanted.entries) {
      final snapshot = _pipeSnapshots[entry.key]!;
      final mid = snapshot.middle;
      var label = _pipeLabels[entry.key];
      if (label == null || !label.isValid()) {
        label = _labelsCollection.addPlacemark();
        final id = entry.key;
        label.addTapListener(
          _flowTapListeners.putIfAbsent(
            'label_$id',
            () => _TapListenerImpl((_) => onPipeTap(id)),
          ),
        );
        _pipeLabels[entry.key] = label;
      }
      label.geometry = ymk.Point(latitude: mid.lat, longitude: mid.lng);
      if (_pipeLabelTexts[entry.key] != entry.value) {
        label.setIconWithStyle(
          _labelIconProvider(entry.value),
          const ymk.IconStyle(anchor: math.Point(0.5, -0.45), zIndex: 4.0),
        );
        _pipeLabelTexts[entry.key] = entry.value;
      }
    }
  }

  /// Re-applies pipe styles (e.g. after switching the "Quyosh" appearance).
  void restylePipes() {
    for (final entry in _pipePolylines.entries) {
      final snapshot = _pipeSnapshots[entry.key];
      if (snapshot != null && entry.value.isValid()) {
        _applyPipeStyle(entry.value, snapshot);
      }
    }
  }

  /// Dashed preview line while drawing a pipe (null clears it).
  void setRubberBand(
    ({double lat, double lng})? from,
    ({double lat, double lng})? to, {
    bool snapped = false,
  }) {
    if (from == null || to == null) {
      final line = _rubberLine;
      if (line != null && line.isValid()) _rubberCollection.remove(line);
      _rubberLine = null;
      return;
    }
    final geometry = ymk.Polyline([
      ymk.Point(latitude: from.lat, longitude: from.lng),
      ymk.Point(latitude: to.lat, longitude: to.lng),
    ]);
    var line = _rubberLine;
    if (line == null || !line.isValid()) {
      line = _rubberCollection.addPolylineWithGeometry(geometry);
      _rubberLine = line;
    } else {
      line.geometry = geometry;
    }
    line.setStrokeColor(snapped ? AppColors.brand : AppColors.ink);
    line.style = ymk.LineStyle(
      strokeWidth: snapped ? 5.0 : 3.5,
      outlineWidth: 2.0,
      outlineColor: Colors.white,
      dashLength: snapped ? 0.0 : 9.0,
      gapLength: snapped ? 0.0 : 6.0,
    );
  }

  static final Map<String, ymk_image.ImageProvider> _labelIconCache = {};

  static ymk_image.ImageProvider _labelIconProvider(String text) {
    return _labelIconCache.putIfAbsent(
      text,
      () => ymk_image.ImageProvider(
        () => _drawLabelImage(text),
        cacheable: true,
        id: 'label_$text',
      ),
    );
  }

  static Future<ui.Image> _drawLabelImage(String text) async {
    final dpr =
        (ui.PlatformDispatcher.instance.views.firstOrNull?.devicePixelRatio ??
                2.75)
            .clamp(2.0, 3.5);
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          color: AppColors.ink,
          fontSize: 11 * dpr,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final padX = 7 * dpr;
    final padY = 3.5 * dpr;
    final w = (painter.width + padX * 2).ceilToDouble();
    final h = (painter.height + padY * 2).ceilToDouble();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, w - 2, h - 2),
      Radius.circular(h / 2),
    );
    canvas.drawRRect(rect, Paint()..color = Colors.white);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = AppColors.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 * dpr,
    );
    painter.paint(canvas, Offset(padX, padY));
    final picture = recorder.endRecording();
    final image = await picture.toImage(w.toInt(), h.toInt());
    picture.dispose();
    return image;
  }

  /// Advances all map animations; called by the screen's ticker (≤ 30 fps).
  void tick() {
    if (!animationsEnabled) return;
    final now = _clock.elapsedMilliseconds;

    final flowPhase = (now % 1000) / 1000.0;
    for (final entry in _flowPolylines.entries) {
      final snapshot = _pipeSnapshots[entry.key];
      final flow = entry.value;
      if (snapshot == null || !flow.isValid() || !flow.visible) continue;
      flow.style = _flowStyle(snapshot, flowPhase * _flowPeriod);
    }

    final pulse = (now % 1600) / 1600.0;
    final pulseScale = 1.0 + 0.9 * Curves.easeOut.transform(pulse);
    for (final halo in _halos.values) {
      if (!halo.isValid()) continue;
      halo.setIconStyle(ymk.IconStyle(scale: pulseScale, zIndex: 9.0));
      halo.opacity = 0.55 * (1.0 - pulse);
    }

    for (final id in _dropInStartMs.keys.toList()) {
      final placemark = _manholePlacemarks[id];
      final snapshot = _manholeSnapshots[id];
      final t = (now - _dropInStartMs[id]!) / 350.0;
      if (placemark == null || snapshot == null || !placemark.isValid()) {
        _dropInStartMs.remove(id);
        continue;
      }
      final done = t >= 1.0;
      placemark.setIconStyle(
        ymk.IconStyle(
          scale: done ? 1.0 : math.max(0.01, Curves.easeOutBack.transform(t)),
          zIndex: snapshot.isSelected ? 20.0 : 10.0,
        ),
      );
      if (done) _dropInStartMs.remove(id);
    }

    for (final id in _drawOnStartMs.keys.toList()) {
      final polyline = _pipePolylines[id];
      final snapshot = _pipeSnapshots[id];
      final t = (now - _drawOnStartMs[id]!) / 500.0;
      if (polyline == null || snapshot == null || !polyline.isValid()) {
        _drawOnStartMs.remove(id);
        continue;
      }
      final k = Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));
      polyline.geometry = snapshot.partial(k);
      if (t >= 1.0) {
        _drawOnStartMs.remove(id);
        final arrow = _pipeArrows[id];
        if (arrow != null && arrow.isValid()) arrow.visible = true;
        final flow = _flowPolylines[id];
        if (flow != null && flow.isValid()) {
          flow.geometry = polyline.geometry;
          flow.visible = true;
        }
      }
    }
  }

  static final Map<String, ymk_image.ImageProvider> _haloIconCache = {};

  static ymk_image.ImageProvider _haloIconProvider(String zoomBucket) {
    final key = 'halo_$zoomBucket';
    return _haloIconCache.putIfAbsent(
      key,
      () => ymk_image.ImageProvider(
        () => _drawHaloImage(zoomBucket == 'dot' ? 16.0 : 40.0),
        cacheable: true,
        id: key,
      ),
    );
  }

  static Future<ui.Image> _drawHaloImage(double diameterDp) async {
    final dpr =
        (ui.PlatformDispatcher.instance.views.firstOrNull?.devicePixelRatio ??
                2.75)
            .clamp(2.0, 3.5);
    final size = ((diameterDp + 8) * dpr).ceilToDouble();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);
    canvas.drawCircle(
      center,
      diameterDp / 2 * dpr,
      Paint()
        ..color = AppColors.inProgress.withValues(alpha: 0.35)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      diameterDp / 2 * dpr,
      Paint()
        ..color = AppColors.inProgress
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * dpr,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    picture.dispose();
    return image;
  }

  static ymk_image.ImageProvider manholeIconProvider(
    ManholeMarkerCacheKey key,
  ) {
    return _manholeIconCache.putIfAbsent(
      key,
      () => ymk_image.ImageProvider(
        () => drawManholeImage(key),
        cacheable: true,
        id: key.id,
      ),
    );
  }

  static ymk_image.ImageProvider _arrowIconProvider(
    WorkStatus status,
    bool isSelected,
  ) {
    final key = 'arrow_${status.name}_${isSelected ? 'sel' : 'norm'}';
    final color = AppColors.forStatus(status);
    return _arrowIconCache.putIfAbsent(
      key,
      () => ymk_image.ImageProvider(
        () => _drawArrowImage(color, isSelected),
        cacheable: true,
        id: key,
      ),
    );
  }

  /// Draws the manhole marker bitmap with Canvas:
  /// - At `zoom < 14` (`zoomBucket == 'dot'`): small `14dp` dot without text.
  /// - At `zoom >= 14` (`zoomBucket == 'full'`): `40dp` diameter circle in status color,
  ///   `2.5dp` white border, soft shadow, centered white bold code text (auto-shrink).
  /// - Selected state: `1.25x` bigger + accent ring.
  static Future<ui.Image> drawManholeImage(
    ManholeMarkerCacheKey key, {
    double? dprOverride,
  }) async {
    final dpr =
        dprOverride ??
        (ui.PlatformDispatcher.instance.views.firstOrNull?.devicePixelRatio ??
                2.75)
            .clamp(2.0, 3.5);
    final isDot = key.zoomBucket == 'dot';
    final scaleFactor = key.selected ? 1.2 : 1.0;

    final baseCircleDiameterDp = isDot ? 14.0 : 44.0;
    final circleDiameterDp = baseCircleDiameterDp * scaleFactor;
    final circleRadiusPx = (circleDiameterDp / 2.0) * dpr;
    final borderWidthPx = (isDot ? 2.0 : 2.5) * dpr;
    final accentRingGapPx = key.selected ? 2.5 * dpr : 0.0;
    final accentRingStrokePx = key.selected ? 2.5 * dpr : 0.0;
    final shadowPadPx = 4.0 * dpr;

    final totalRadiusPx =
        circleRadiusPx +
        borderWidthPx +
        accentRingGapPx +
        accentRingStrokePx +
        shadowPadPx;
    final canvasSizePx = (totalRadiusPx * 2.0).ceilToDouble();
    final center = Offset(canvasSizePx / 2.0, canvasSizePx / 2.0);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final statusColor = AppColors.forStatus(key.status);

    // Soft drop shadow
    final shadowPaint = Paint()
      ..color = AppColors.ink.withValues(alpha: 0.28)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.4 * dpr);
    canvas.drawCircle(
      center.translate(0, 1.4 * dpr),
      circleRadiusPx + borderWidthPx,
      shadowPaint,
    );

    // Selected: brand halo + ring
    if (key.selected) {
      canvas.drawCircle(
        center,
        circleRadiusPx + borderWidthPx + accentRingGapPx + accentRingStrokePx,
        Paint()..color = AppColors.brand.withValues(alpha: 0.18),
      );
      canvas.drawCircle(
        center,
        circleRadiusPx +
            borderWidthPx +
            accentRingGapPx +
            accentRingStrokePx / 2.0,
        Paint()
          ..color = AppColors.brand
          ..style = PaintingStyle.stroke
          ..strokeWidth = accentRingStrokePx,
      );
    }

    final planned = key.status == WorkStatus.planned;

    // White cover base
    canvas.drawCircle(
      center,
      circleRadiusPx + borderWidthPx,
      Paint()..color = Colors.white,
    );

    if (isDot) {
      // Planned dot is hollow ("not built yet"), others filled.
      canvas.drawCircle(
        center,
        circleRadiusPx,
        Paint()
          ..color = statusColor
          ..style = planned ? PaintingStyle.stroke : PaintingStyle.fill
          ..strokeWidth = 2.6 * dpr,
      );
    } else {
      // Manhole cover seen from above: outer status ring (dashed when
      // planned), white gap, status disc with a thin concentric groove.
      final ringStroke = 3.0 * dpr;
      final ringRadius = circleRadiusPx - ringStroke / 2;
      final ringPaint = Paint()
        ..color = statusColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringStroke;
      if (planned) {
        const segments = 14;
        const sweep = 2 * math.pi / segments;
        final rect = Rect.fromCircle(center: center, radius: ringRadius);
        for (var i = 0; i < segments; i++) {
          canvas.drawArc(rect, i * sweep, sweep * 0.6, false, ringPaint);
        }
      } else {
        canvas.drawCircle(center, ringRadius, ringPaint);
      }

      final discRadius = circleRadiusPx - 5.5 * dpr * scaleFactor;
      canvas.drawCircle(
        center,
        discRadius,
        Paint()..color = planned ? statusColor.withValues(alpha: 0.85) : statusColor,
      );
      canvas.drawCircle(
        center,
        discRadius - 2.6 * dpr,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0 * dpr,
      );

      // Completed: small check badge at the bottom-right.
      if (key.status == WorkStatus.completed) {
        final badgeCenter = center.translate(
          circleRadiusPx * 0.72,
          circleRadiusPx * 0.72,
        );
        final badgeRadius = 6.0 * dpr;
        canvas.drawCircle(
          badgeCenter,
          badgeRadius + 1.2 * dpr,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(
          badgeCenter,
          badgeRadius,
          Paint()..color = AppColors.completed,
        );
        final check = Path()
          ..moveTo(badgeCenter.dx - 2.8 * dpr, badgeCenter.dy + 0.2 * dpr)
          ..lineTo(badgeCenter.dx - 0.8 * dpr, badgeCenter.dy + 2.2 * dpr)
          ..lineTo(badgeCenter.dx + 3.0 * dpr, badgeCenter.dy - 2.0 * dpr);
        canvas.drawPath(
          check,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6 * dpr
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
    }

    // Manhole code centered inside in white bold text (only when zoom >= 14)
    if (!isDot && key.code.trim().isNotEmpty) {
      final label = key.code.trim();
      final maxTextWidth = (circleRadiusPx * 2.0) * 0.6;
      var fontSizePx = (12.0 * scaleFactor) * dpr;
      final minFontSizePx = 7.0 * dpr;

      late TextPainter textPainter;
      while (true) {
        textPainter = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: Colors.white,
              fontSize: fontSizePx,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              height: 1.0,
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();

        if (textPainter.width <= maxTextWidth || fontSizePx <= minFontSizePx) {
          break;
        }
        fontSizePx -= 0.75 * dpr;
      }

      final textOffset = Offset(
        center.dx - textPainter.width / 2.0,
        center.dy - textPainter.height / 2.0,
      );
      textPainter.paint(canvas, textOffset);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      canvasSizePx.toInt(),
      canvasSizePx.toInt(),
    );
    picture.dispose();
    return image;
  }

  static Future<ui.Image> _drawArrowImage(
    Color color,
    bool isSelected,
  ) async {
    final dpr =
        (ui.PlatformDispatcher.instance.views.firstOrNull?.devicePixelRatio ??
                2.75)
            .clamp(2.0, 3.5);
    final sizeDp = isSelected ? 22.0 : 18.0;
    final size = (sizeDp * dpr).ceilToDouble();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final cx = size / 2;
    final topY = size * 0.16;
    final bottomY = size * 0.82;
    final halfWidth = size * 0.34;
    final notchY = size * 0.66;

    final path = Path()
      ..moveTo(cx, topY)
      ..lineTo(cx + halfWidth, bottomY)
      ..lineTo(cx, notchY)
      ..lineTo(cx - halfWidth, bottomY)
      ..close();

    final outlinePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * dpr
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, outlinePaint);

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    picture.dispose();
    return image;
  }
}
