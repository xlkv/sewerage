import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import '../../shared/widgets/map_controls.dart';
import 'network_stats_card.dart';
import 'feature_providers.dart';
import 'map_overlays.dart';
import 'network_graph.dart';
import '../report/network_report.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:yandex_maps_mapkit_lite/mapkit.dart' as ymk;
import 'package:yandex_maps_mapkit_lite/mapkit_factory.dart';
import 'package:yandex_maps_mapkit_lite/yandex_map.dart';

import '../../core/env.dart';
import '../../core/errors.dart';
import '../../core/geo_utils.dart';
import '../../core/theme.dart';
import '../../data/models/manhole.dart';
import '../../data/models/master.dart';
import '../../data/models/pipe.dart';
import '../../data/models/work_status.dart';
import '../../data/repositories/auth_repo.dart';
import '../../data/repositories/manhole_repo.dart';
import '../../data/repositories/master_repo.dart';
import '../../data/repositories/pipe_repo.dart';
import '../../shared/widgets/adaptive_panel.dart';
import '../manhole/manhole_details.dart';
import '../manhole/manhole_form.dart';
import '../pipe/pipe_details.dart';
import '../pipe/pipe_form.dart';
import 'filter_sheet.dart';
import 'map_controller.dart';
import 'map_mode.dart';
import 'map_objects_layer.dart';

class _MapInputListenerImpl implements ymk.MapInputListener {
  final void Function(ymk.Point point) onTap;

  _MapInputListenerImpl({required this.onTap});

  @override
  void onMapTap(ymk.Map map, ymk.Point point) => onTap(point);

  @override
  void onMapLongTap(ymk.Map map, ymk.Point point) {}
}

class _MapCameraListenerImpl implements ymk.MapCameraListener {
  final void Function(ymk.CameraPosition position) onCameraChanged;

  _MapCameraListenerImpl({required this.onCameraChanged});

  @override
  void onCameraPositionChanged(
    ymk.Map map,
    ymk.CameraPosition cameraPosition,
    ymk.CameraUpdateReason cameraUpdateReason,
    bool finished,
  ) {
    onCameraChanged(cameraPosition);
  }
}

class _SatelliteTilesUrlProvider implements ymk.TilesUrlProvider {
  const _SatelliteTilesUrlProvider();

  @override
  String formatUrl(
    ymk.TileId tileId,
    ymk.Version version,
    Map<String, String> features,
  ) {
    return 'https://core-sat.maps.yandex.net/tiles?l=sat&x=${tileId.x}&y=${tileId.y}&z=${tileId.z}&scale=1&lang=ru_RU';
  }
}

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const double _qarshiLat = GeoUtils.qarshiLat;
  static const double _qarshiLng = GeoUtils.qarshiLng;
  static const double _defaultZoom = GeoUtils.qarshiDefaultZoom;
  static const String _satelliteLayerId = 'turon_satellite_layer';
  static const String _networkObjectsLayerId = 'turon_network_objects';

  ymk.MapWindow? _mapWindow;
  ymk.Layer? _satelliteLayer;
  final ymk.TilesUrlProvider _satelliteUrlProvider =
      const _SatelliteTilesUrlProvider();
  ymk.CreateTileDataSource? _satelliteDataSourceFactory;
  MapObjectsLayerController? _layerController;
  ymk.MapInputListener? _inputListener;
  ymk.MapCameraListener? _cameraListener;
  AppLifecycleListener? _lifecycleListener;

  double _currentZoom = _defaultZoom;
  bool _initialCameraApplied = false;
  bool _savingMove = false;
  bool _locatingGps = false;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  ({double lat, double lng})? _cameraTarget;
  final _rubberInfo = ValueNotifier<RubberBandInfo?>(null);
  String? _lastSnapId;
  Timer? _timelineTimer;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        _appActive = true;
        _updateAnimationLoop();
        if (Env.isMapkitConfigured) {
          try {
            mapkit.onStart();
          } catch (_) {}
        }
      },
      onPause: () {
        _appActive = false;
        _updateAnimationLoop();
        if (Env.isMapkitConfigured) {
          try {
            mapkit.onStop();
          } catch (_) {}
        }
      },
    );
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    _timelineTimer?.cancel();
    _timelineSyncTimer?.cancel();
    _rubberInfo.dispose();
    _lifecycleListener?.dispose();
    final map = _mapWindow?.map;
    if (map != null && map.isValid()) {
      if (_inputListener != null) {
        map.removeInputListener(_inputListener!);
      }
      if (_cameraListener != null) {
        map.removeCameraListener(_cameraListener!);
      }
    }
    if (Env.isMapkitConfigured) {
      try {
        mapkit.onStop();
      } catch (_) {}
    }
    super.dispose();
  }

  void _onMapCreated(ymk.MapWindow window) {
    _mapWindow = window;
    if (Env.isMapkitConfigured) {
      try {
        mapkit.onStart();
      } catch (_) {}
    }

    final map = window.map;
    debugPrint(
      'TuronMapKit: YandexMap onMapCreated (mapValid=${map.isValid()})',
    );
    _initSatelliteTileLayer(map, ref.read(mapLayerProvider));
    _applyAppearance(ref.read(mapAppearanceProvider));

    _inputListener = _MapInputListenerImpl(
      onTap: (point) {
        ref
            .read(mapControllerProvider.notifier)
            .onMapTap(point.latitude, point.longitude);
      },
    );
    map.addInputListener(_inputListener!);

    _cameraListener = _MapCameraListenerImpl(
      onCameraChanged: (position) {
        final zoom = position.zoom;
        final prevBucket = MapObjectsLayer.zoomBucket(_currentZoom);
        final nextBucket = MapObjectsLayer.zoomBucket(zoom);
        const labelZoom = MapObjectsLayer.pipeLabelMinZoom;
        final labelsChanged =
            (_currentZoom >= labelZoom) != (zoom >= labelZoom);
        _currentZoom = zoom;
        _cameraTarget = (
          lat: position.target.latitude,
          lng: position.target.longitude,
        );
        if (prevBucket != nextBucket || labelsChanged) {
          _syncMapObjects();
        }
        _updateRubberBand();
      },
    );
    map.addCameraListener(_cameraListener!);

    ymk.MapObjectCollection rootObjectsCollection;
    try {
      rootObjectsCollection = map.addMapObjectLayer(_networkObjectsLayerId);
    } catch (_) {
      rootObjectsCollection = map.mapObjects;
    }

    _layerController = MapObjectsLayerController(
      rootCollection: rootObjectsCollection,
      onManholeTap: (manholeId) {
        final pipes = ref.read(pipesProvider).asData?.value.values ?? const [];
        ref
            .read(mapControllerProvider.notifier)
            .onManholeTap(manholeId, existingPipes: pipes);
      },
      onPipeTap: (pipeId) {
        ref.read(mapControllerProvider.notifier).onPipeTap(pipeId);
      },
      onManholeMoved: (lat, lng) {
        ref
            .read(mapControllerProvider.notifier)
            .updateMoveManholePosition(lat, lng);
      },
    );

    // Move to Qarshi city center immediately before async data arrives.
    _moveCamera(
      const ymk.CameraPosition(
        ymk.Point(latitude: _qarshiLat, longitude: _qarshiLng),
        zoom: _defaultZoom,
        azimuth: 0,
        tilt: 0,
      ),
      animated: false,
    );

    final manholesData = ref.read(manholesProvider).asData?.value;
    if (manholesData != null && !_initialCameraApplied) {
      _applyInitialCamera(manholesData);
    }

    _syncMapObjects();
  }

  /// Desaturated base map so the network stands out (DESIGN §2).
  static const String _blueprintMapStyle =
      '[{"tags":{"any":["poi"]},"stylers":{"visibility":"off"}},'
      '{"stylers":{"saturation":-0.8,"lightness":0.12}}]';

  void _applyAppearance(MapAppearance appearance) {
    final map = _mapWindow?.map;
    if (map == null || !map.isValid()) return;
    try {
      final ok = map.setMapStyle(
        appearance == MapAppearance.blueprint ? _blueprintMapStyle : '[]',
      );
      map.nightModeEnabled = appearance == MapAppearance.night;
      debugPrint('TuronMapKit: map appearance=${appearance.name} style=$ok');
    } catch (e) {
      debugPrint('TuronMapKit: map appearance failed: $e');
    }
    final controller = _layerController;
    if (controller != null &&
        controller.highContrast != (appearance == MapAppearance.sun)) {
      controller.highContrast = appearance == MapAppearance.sun;
      controller.restylePipes();
    }
  }

  /// Live data, or the network as it was at the timeline's date.
  ({Map<String, Manhole> manholes, Map<String, Pipe> pipes}) _networkData() {
    final manholes = ref.read(manholesProvider).asData?.value ?? const {};
    final pipes = ref.read(pipesProvider).asData?.value ?? const {};
    final timeline = ref.read(timelineProvider);
    if (timeline == null) return (manholes: manholes, pipes: pipes);
    final events = ref.read(statusEventsProvider).asData?.value ?? const [];
    final snap = NetworkSnapshot.at(timeline.at, manholes, pipes, events);
    return (manholes: snap.manholes, pipes: snap.pipes);
  }

  /// Rubber band from the first chosen manhole to the map centre; snaps to
  /// a manhole near the centre (≈ 28 dp).
  void _updateRubberBand() {
    final controller = _layerController;
    final mode = ref.read(mapControllerProvider).mode;
    final manholes = ref.read(manholesProvider).asData?.value ?? const {};
    final from = mode is AddPipeMode && mode.fromManholeId != null
        ? manholes[mode.fromManholeId]
        : null;
    final target = _cameraTarget;
    if (controller == null || from == null || target == null) {
      controller?.setRubberBand(null, null);
      _rubberInfo.value = null;
      _lastSnapId = null;
      return;
    }
    final metersPerDp =
        156543.03392 *
        math.cos(target.lat * math.pi / 180) /
        math.pow(2, _currentZoom);
    final threshold = 28 * metersPerDp;
    Manhole? snap;
    var best = double.infinity;
    for (final m in manholes.values) {
      if (m.id == from.id) continue;
      final d = GeoUtils.haversineMeters(target.lat, target.lng, m.lat, m.lng);
      if (d < threshold && d < best) {
        best = d;
        snap = m;
      }
    }
    final end = snap != null ? (lat: snap.lat, lng: snap.lng) : target;
    controller.setRubberBand(
      (lat: from.lat, lng: from.lng),
      end,
      snapped: snap != null,
    );
    if (snap?.id != _lastSnapId) {
      _lastSnapId = snap?.id;
      if (snap != null) HapticFeedback.selectionClick();
    }
    _rubberInfo.value = RubberBandInfo(
      meters: GeoUtils.haversineMeters(from.lat, from.lng, end.lat, end.lng),
      snappedId: snap?.id,
      snappedCode: snap?.code,
    );
  }

  Timer? _timelineSyncTimer;

  void _scheduleTimelineSync() {
    if (_timelineSyncTimer != null) return;
    _timelineSyncTimer = Timer(const Duration(milliseconds: 150), () {
      _timelineSyncTimer = null;
      if (mounted) _syncMapObjects();
    });
  }

  void _updateTimelineLoop(TimelineState? timeline) {
    final playing = timeline?.playing ?? false;
    if (playing && _timelineTimer == null) {
      var last = DateTime.now();
      _timelineTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        final now = DateTime.now();
        ref.read(timelineProvider.notifier).step(now.difference(last));
        last = now;
      });
    } else if (!playing) {
      _timelineTimer?.cancel();
      _timelineTimer = null;
    }
  }

  void _fitTo(Iterable<({double lat, double lng})> points) {
    final list = points.toList();
    if (list.isEmpty) return;
    var minLat = list.first.lat, maxLat = list.first.lat;
    var minLng = list.first.lng, maxLng = list.first.lng;
    for (final p in list) {
      minLat = math.min(minLat, p.lat);
      maxLat = math.max(maxLat, p.lat);
      minLng = math.min(minLng, p.lng);
      maxLng = math.max(maxLng, p.lng);
    }
    final spanM = math.max(
      GeoUtils.haversineMeters(minLat, minLng, maxLat, minLng),
      GeoUtils.haversineMeters(minLat, minLng, minLat, maxLng),
    );
    // Leave room for the floating top panel/legend and the bottom controls.
    final widthDp = MediaQuery.sizeOf(context).width * 0.6;
    final metersPerDp = math.max(spanM, 60) / widthDp;
    final zoom = (math.log(
              156543.03392 *
                  math.cos((minLat + maxLat) / 2 * math.pi / 180) /
                  metersPerDp,
            ) /
            math.ln2)
        .clamp(3.0, 18.0);
    _moveCamera(
      ymk.CameraPosition(
        ymk.Point(
          latitude: (minLat + maxLat) / 2 + (maxLat - minLat) * 0.18,
          longitude: (minLng + maxLng) / 2,
        ),
        zoom: zoom,
        azimuth: 0,
        tilt: 0,
      ),
    );
  }

  Future<void> _shareReport() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Hisobot tayyorlanmoqda…')),
    );
    try {
      final bytes = await NetworkReport.build(
        manholes: ref.read(manholesProvider).asData?.value ?? const {},
        pipes: ref.read(pipesProvider).asData?.value ?? const {},
        masters: ref.read(mastersProvider).asData?.value ?? const [],
      );
      final d = DateTime.now();
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'turon-hisobot-${d.year}-${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}.pdf',
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Hisobot tayyorlab bo\'lmadi: $e')),
      );
    }
  }

  void _openSearch() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SearchSheet(
        manholes: ref.read(manholesProvider).asData?.value ?? const {},
        pipes: ref.read(pipesProvider).asData?.value ?? const {},
        onSelect: (selection) {
          Navigator.of(sheetContext).pop();
          ref.read(traceProvider.notifier).clear();
          ref.read(mapControllerProvider.notifier).select(selection);
        },
      ),
    );
  }

  void _openTimeline() {
    final events = ref.read(statusEventsProvider).asData?.value ?? const [];
    ref.read(mapControllerProvider.notifier).clearSelection();
    ref.read(traceProvider.notifier).clear();
    ref.read(timelineProvider.notifier).open(events);
  }

  // One ticker for all map animations; runs only while something animates
  // and the app is in the foreground.
  Timer? _animationTimer;
  bool _appActive = true;

  void _updateAnimationLoop() {
    final controller = _layerController;
    final needed =
        _appActive && controller != null && controller.hasActiveAnimations;
    if (needed && _animationTimer == null) {
      _animationTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
        final c = _layerController;
        if (!_appActive || c == null || !c.hasActiveAnimations) {
          _animationTimer?.cancel();
          _animationTimer = null;
          return;
        }
        c.tick();
      });
    } else if (!needed) {
      _animationTimer?.cancel();
      _animationTimer = null;
    }
  }

  void _initSatelliteTileLayer(ymk.Map map, MapLayer initialLayer) {
    map.mapType = ymk.MapType.VectorMap;
    final isSatellite = initialLayer == MapLayer.satellite;
    try {
      _satelliteDataSourceFactory = ymk.CreateTileDataSource(
        createTileDataSource: (builder) {
          builder.setTileUrlProvider(_satelliteUrlProvider);
          builder.setProjection(ymk.Projections.wgs84Mercator);
          builder.setTileFormat(ymk.TileFormat.Jpg);
          builder.setZoomRanges(const [
            ymk.ZoomRangeIdl(zMin: 0, zMax: 20),
          ]);
        },
      );
      _satelliteLayer = map.addTileLayer(
        ymk.LayerOptions(
          active: isSatellite,
          nightModeAvailable: false,
          cacheable: true,
          animateOnActivation: true,
          overzoomMode: ymk.OverzoomMode.WithPrefetch,
          versionSupport: false,
        ),
        _satelliteDataSourceFactory!,
        layerId: _satelliteLayerId,
      );
    } catch (e) {
      debugPrint('TuronMapKit: failed to init satellite tile layer: $e');
    }
  }

  void _applyMapLayer(MapLayer layer) {
    final map = _mapWindow?.map;
    if (map == null || !map.isValid()) return;
    map.mapType = ymk.MapType.VectorMap;
    final isSatellite = layer == MapLayer.satellite;
    final satLayer = _satelliteLayer;
    if (satLayer != null && satLayer.isValid()) {
      final dataSourceLayer = satLayer.dataSourceLayer();
      if (dataSourceLayer.isValid()) {
        dataSourceLayer.active = isSatellite;
      }
    }
  }

  void _focusSelectedObject(Selection selection) {
    if (!mounted) return;
    final map = _mapWindow?.map;
    if (map == null || !map.isValid()) return;

    final allManholes = ref.read(manholesProvider).asData?.value ?? const {};
    final allPipes = ref.read(pipesProvider).asData?.value ?? const {};
    final anchor = MapObjectsLayer.selectionAnchorPoint(
      selection: selection,
      allManholes: allManholes,
      allPipes: allPipes,
    );
    if (anchor == null) return;

    final isWide = AdaptivePanel.isTablet(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final bottomSheetHeightDp = isWide ? 0.0 : screenHeight * 0.38;
    final targetZoom = _currentZoom < 15.0 ? 15.5 : _currentZoom;

    final target = GeoUtils.offsetCameraTargetForSheet(
      objectLat: anchor.lat,
      objectLng: anchor.lng,
      zoom: targetZoom,
      bottomSheetHeightDp: bottomSheetHeightDp,
    );

    _moveCamera(
      ymk.CameraPosition(
        ymk.Point(latitude: target.lat, longitude: target.lng),
        zoom: targetZoom,
        azimuth: 0,
        tilt: 0,
      ),
      animated: true,
    );
  }

  void _moveCamera(ymk.CameraPosition position, {bool animated = true}) {
    final map = _mapWindow?.map;
    if (map == null || !map.isValid()) return;
    final prevBucket = MapObjectsLayer.zoomBucket(_currentZoom);
    final nextBucket = MapObjectsLayer.zoomBucket(position.zoom);
    if (animated) {
      map.move(
        position,
        animation: const ymk.Animation(
          type: ymk.AnimationType.Smooth,
          duration: 0.4,
        ),
      );
    } else {
      map.move(position);
    }
    _currentZoom = position.zoom;
    if (prevBucket != nextBucket) {
      _syncMapObjects();
    }
  }


  Future<void> _applyInitialCamera(Map<String, Manhole> manholes) async {
    final map = _mapWindow?.map;
    if (map == null || !map.isValid() || _initialCameraApplied) return;
    _initialCameraApplied = true;

    if (manholes.isNotEmpty) {
      if (manholes.length == 1) {
        final single = manholes.values.first;
        _moveCamera(
          ymk.CameraPosition(
            ymk.Point(latitude: single.lat, longitude: single.lng),
            zoom: 16.0,
            azimuth: 0,
            tilt: 0,
          ),
        );
        return;
      }

      final bbox = GeoUtils.boundingBox(
        manholes.values.map((m) => (lat: m.lat, lng: m.lng)),
      );
      if (bbox != null) {
        if ((bbox.maxLat - bbox.minLat).abs() < 1e-6 &&
            (bbox.maxLng - bbox.minLng).abs() < 1e-6) {
          _moveCamera(
            ymk.CameraPosition(
              ymk.Point(latitude: bbox.minLat, longitude: bbox.minLng),
              zoom: 16.0,
              azimuth: 0,
              tilt: 0,
            ),
          );
          return;
        }
        try {
          final geometry = ymk.Geometry.fromBoundingBox(
            ymk.BoundingBox(
              ymk.Point(latitude: bbox.minLat, longitude: bbox.minLng),
              ymk.Point(latitude: bbox.maxLat, longitude: bbox.maxLng),
            ),
          );
          final pos = map.cameraPositionForGeometry(geometry);
          final adjustedZoom = (pos.zoom - 0.3).clamp(3.0, 17.0);
          if (adjustedZoom >= MapObjectsLayer.codeMinZoom) {
            _moveCamera(
              ymk.CameraPosition(
                pos.target,
                zoom: adjustedZoom,
                azimuth: 0,
                tilt: 0,
              ),
            );
            return;
          }
          // When distant outlier manholes pull bounding-box zoom below 14,
          // focus on the manhole closest to Qarshi at zoom 15.5 so code labels are visible.
          Manhole? nearestToQarshi;
          var bestDist = double.infinity;
          for (final m in manholes.values) {
            final d = GeoUtils.spheroidMeters(
              _qarshiLat,
              _qarshiLng,
              m.lat,
              m.lng,
            );
            if (d < bestDist) {
              bestDist = d;
              nearestToQarshi = m;
            }
          }
          if (nearestToQarshi != null) {
            _moveCamera(
              ymk.CameraPosition(
                ymk.Point(
                  latitude: nearestToQarshi.lat,
                  longitude: nearestToQarshi.lng,
                ),
                zoom: 15.5,
                azimuth: 0,
                tilt: 0,
              ),
            );
            return;
          }
        } catch (_) {}
      }
    }

    // No manholes yet -> Qarshi city center (no auto-GPS jump on start).
    if (!mounted) return;
    _moveCamera(
      const ymk.CameraPosition(
        ymk.Point(latitude: _qarshiLat, longitude: _qarshiLng),
        zoom: _defaultZoom,
        azimuth: 0,
        tilt: 0,
      ),
    );
  }

  Future<void> _jumpToMyLocation() async {
    if (_locatingGps) return;
    setState(() => _locatingGps = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joylashuv xizmati (GPS) yoqilmagan')),
        );
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joylashuvga ruxsat berilmadi')),
        );
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 6),
        ),
      );
      if (!mounted) return;
      _moveCamera(
        ymk.CameraPosition(
          ymk.Point(latitude: pos.latitude, longitude: pos.longitude),
          zoom: 16.0,
          azimuth: 0,
          tilt: 0,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Joriy joylashuvni aniqlab bo\'lmadi')),
      );
    } finally {
      if (mounted) {
        setState(() => _locatingGps = false);
      }
    }
  }

  void _syncMapObjects() {
    final controller = _layerController;
    if (controller == null) return;

    final data = _networkData();
    final allManholes = data.manholes;
    final allPipes = data.pipes;
    final activeStatuses = ref.read(statusFilterProvider);
    final mapState = ref.read(mapControllerProvider);
    final traceId = ref.read(traceProvider);
    final trace = traceId != null && ref.read(timelineProvider) == null
        ? NetworkGraph.trace(traceId, allPipes.values)
        : null;

    controller.animationsEnabled = !MediaQuery.disableAnimationsOf(context);
    controller.sync(
      allManholes: allManholes,
      allPipes: allPipes,
      activeStatuses: activeStatuses,
      selection: mapState.selection,
      mode: mapState.mode,
      zoom: _currentZoom,
      trace: trace,
    );
    _updateAnimationLoop();
  }

  Future<void> _saveMoveManhole(MoveManholeMode mode) async {
    setState(() => _savingMove = true);
    try {
      final moved = await ref
          .read(manholeRepoProvider)
          .move(
            mode.manholeId,
            lat: mode.newLat,
            lng: mode.newLng,
          );
      final currentManholes =
          ref.read(manholesProvider).asData?.value ?? const {};
      ref
          .read(pipeRepoProvider)
          .recalculateForMovedManhole(
            moved,
            {...currentManholes, moved.id: moved},
          );
      if (!mounted) return;
      ref.read(mapControllerProvider.notifier).completeMoveManhole();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kolodets joyi saqlandi')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapErrorToMessage(e))),
      );
    } finally {
      if (mounted) {
        setState(() => _savingMove = false);
      }
    }
  }

  Widget? _buildActiveForm({
    required ActiveForm? activeForm,
    required Map<String, Manhole> manholes,
    required Map<String, Pipe> pipes,
    required List<Master> masters,
  }) {
    if (activeForm == null) return null;
    final notifier = ref.read(mapControllerProvider.notifier);

    return switch (activeForm) {
      CreateManholeForm(:final lat, :final lng) => ManholeForm(
        key: ValueKey('create_manhole_${lat}_$lng'),
        initialLat: lat,
        initialLng: lng,
        masters: masters,
        onSaved: (saved) =>
            notifier.onFormSaved(selection: ManholeSelection(saved.id)),
        onCancel: notifier.closeForm,
      ),
      EditManholeForm(:final manholeId) =>
        manholes[manholeId] != null
            ? ManholeForm(
                key: ValueKey('edit_manhole_$manholeId'),
                existing: manholes[manholeId],
                masters: masters,
                onSaved: (saved) =>
                    notifier.onFormSaved(selection: ManholeSelection(saved.id)),
                onCancel: notifier.closeForm,
              )
            : null,
      CreatePipeForm(:final fromManholeId, :final toManholeId) => PipeForm(
        key: ValueKey('create_pipe_${fromManholeId}_$toManholeId'),
        initialFromManholeId: fromManholeId,
        initialToManholeId: toManholeId,
        allManholes: manholes,
        onSaved: (saved) =>
            notifier.onFormSaved(selection: PipeSelection(saved.id)),
        onCancel: notifier.closeForm,
      ),
      EditPipeForm(:final pipeId) =>
        pipes[pipeId] != null
            ? PipeForm(
                key: ValueKey('edit_pipe_$pipeId'),
                existing: pipes[pipeId],
                allManholes: manholes,
                onSaved: (saved) =>
                    notifier.onFormSaved(selection: PipeSelection(saved.id)),
                onCancel: notifier.closeForm,
              )
            : null,
    };
  }

  Widget Function(BuildContext, ScrollController?)? _buildDetailsBuilder({
    required Selection? selection,
    required MapMode mode,
    required Map<String, Manhole> manholes,
    required Map<String, Pipe> pipes,
    required List<Master> masters,
    required bool isAdmin,
  }) {
    if (mode is! ViewMode || selection == null) return null;
    final notifier = ref.read(mapControllerProvider.notifier);

    switch (selection) {
      case ManholeSelection(:final id):
        final manhole = manholes[id];
        if (manhole == null) return null;
        return (context, scrollController) => ManholeDetails(
          key: ValueKey('details_manhole_$id'),
          manhole: manhole,
          allManholes: manholes,
          allPipes: pipes,
          masters: masters,
          isAdmin: isAdmin,
          scrollController: scrollController,
          onClose: notifier.clearSelection,
          onEdit: () => notifier.openEditManholeForm(id, isAdmin: isAdmin),
          onMove: () => notifier.startMoveManhole(
            id,
            initialLat: manhole.lat,
            initialLng: manhole.lng,
            isAdmin: isAdmin,
          ),
          onSelectPipe: (pipeId) => notifier.select(PipeSelection(pipeId)),
          onDeleted: notifier.clearSelection,
          onTrace: () {
            ref.read(traceProvider.notifier).show(id);
            notifier.clearSelection();
          },
        );
      case PipeSelection(:final id):
        final pipe = pipes[id];
        if (pipe == null) return null;
        return (context, scrollController) => PipeDetails(
          key: ValueKey('details_pipe_$id'),
          pipe: pipe,
          allManholes: manholes,
          isAdmin: isAdmin,
          scrollController: scrollController,
          onClose: notifier.clearSelection,
          onEdit: () => notifier.openEditPipeForm(id, isAdmin: isAdmin),
          onSelectManhole: (manholeId) =>
              notifier.select(ManholeSelection(manholeId)),
          onDeleted: notifier.clearSelection,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final manholesAsync = ref.watch(manholesProvider);
    final pipesAsync = ref.watch(pipesProvider);
    final mastersAsync = ref.watch(mastersProvider);
    final mapState = ref.watch(mapControllerProvider);
    final mapLayer = ref.watch(mapLayerProvider);
    final activeStatuses = ref.watch(statusFilterProvider);
    final traceId = ref.watch(traceProvider);
    final timeline = ref.watch(timelineProvider);
    ref.watch(statusEventsProvider);

    ref.listen<MapLayer>(mapLayerProvider, (_, next) {
      _applyMapLayer(next);
    });

    ref.listen<MapAppearance>(mapAppearanceProvider, (_, next) {
      _applyAppearance(next);
    });

    ref.listen<String?>(traceProvider, (_, next) {
      _syncMapObjects();
      if (next == null) return;
      final manholes = ref.read(manholesProvider).asData?.value ?? const {};
      final pipes = ref.read(pipesProvider).asData?.value ?? const {};
      final t = NetworkGraph.trace(next, pipes.values);
      _fitTo([
        for (final id in {next, ...t.downstreamManholes, ...t.upstreamManholes})
          if (manholes[id] != null) (lat: manholes[id]!.lat, lng: manholes[id]!.lng),
      ]);
    });

    ref.listen<TimelineState?>(timelineProvider, (prev, next) {
      _updateTimelineLoop(next);
      // During playback the date moves every 50 ms; redrawing ~1000 map
      // objects that often blocks the UI, so sync at most every 150 ms.
      if (next != null && next.playing && prev != null) {
        _scheduleTimelineSync();
      } else {
        _timelineSyncTimer?.cancel();
        _timelineSyncTimer = null;
        _syncMapObjects();
      }
    });

    ref.listen(statusEventsProvider, (_, _) {
      if (ref.read(timelineProvider) != null) _syncMapObjects();
    });

    ref.listen<MapState>(mapControllerProvider, (prev, next) {
      if (next.snackbarMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.snackbarMessage!)),
        );
        ref.read(mapControllerProvider.notifier).clearSnackbar();
      }
      _syncMapObjects();
      _updateRubberBand();
      if (next.selection != null &&
          next.selection != prev?.selection &&
          next.mode is ViewMode &&
          next.activeForm == null) {
        _focusSelectedObject(next.selection!);
      }
    });

    ref.listen<AsyncValue<Map<String, Manhole>>>(manholesProvider, (_, next) {
      final data = next.asData?.value;
      if (data != null && !_initialCameraApplied) {
        _applyInitialCamera(data);
      }
      _syncMapObjects();
    });

    ref.listen<AsyncValue<Map<String, Pipe>>>(pipesProvider, (_, _) {
      _syncMapObjects();
    });

    ref.listen<Set<WorkStatus>>(statusFilterProvider, (_, _) {
      _syncMapObjects();
    });

    final profile = profileAsync.asData?.value;
    final isAdmin = profile?.isAdmin ?? false;

    final allManholes = manholesAsync.asData?.value ?? const {};
    final allPipes = pipesAsync.asData?.value ?? const {};
    final allMasters = mastersAsync.asData?.value ?? const [];

    final visibleManholes = MapObjectsLayer.filterManholes(
      allManholes,
      activeStatuses,
    );
    final visiblePipes = MapObjectsLayer.filterPipes(
      allPipes,
      activeStatuses,
      allManholes: allManholes,
    );

    final isOffline = manholesAsync.hasError || pipesAsync.hasError;

    final formChild = _buildActiveForm(
      activeForm: mapState.activeForm,
      manholes: allManholes,
      pipes: allPipes,
      masters: allMasters,
    );

    final net = _networkData();
    final detailsBuilder = timeline != null
        ? null
        : _buildDetailsBuilder(
      selection: mapState.selection,
      mode: mapState.mode,
      manholes: allManholes,
      pipes: allPipes,
      masters: allMasters,
      isAdmin: isAdmin,
    );

    final canPopDirectly =
        mapState.mode is ViewMode &&
        mapState.activeForm == null &&
        mapState.selection == null;

    return PopScope(
      canPop: canPopDirectly,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          final notifier = ref.read(mapControllerProvider.notifier);
          if (mapState.mode is ViewMode &&
              mapState.activeForm == null &&
              mapState.selection != null) {
            notifier.clearSelection();
          } else {
            notifier.cancelMode();
          }
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: _TuronNavigationDrawer(
          isAdmin: isAdmin,
          fullName: profile?.fullName,
          onTimeline: _openTimeline,
          onReport: _shareReport,
          onSignOut: () async {
            await ref.read(authRepoProvider).signOut();
          },
        ),
        body: AdaptivePanel(
          formChild: formChild,
          detailsBuilder: detailsBuilder,
          detailsKey: mapState.selection,
          onDismissDetails: () =>
              ref.read(mapControllerProvider.notifier).clearSelection(),
          mapChild: Stack(
            children: [
              Positioned.fill(
                child: Env.isMapkitConfigured
                    ? YandexMap(
                        onMapCreated: _onMapCreated,
                        platformViewType: PlatformViewType.Hybrid,
                      )
                    : _MapPlaceholderCanvas(
                        manholes: visibleManholes,
                        allManholes: allManholes,
                        pipes: visiblePipes,
                        selection: mapState.selection,
                        mode: mapState.mode,
                        onMapTap: (lat, lng) => ref
                            .read(mapControllerProvider.notifier)
                            .onMapTap(lat, lng),
                        onManholeTap: (id) => ref
                            .read(mapControllerProvider.notifier)
                            .onManholeTap(id, existingPipes: allPipes.values),
                        onPipeTap: (id) => ref
                            .read(mapControllerProvider.notifier)
                            .onPipeTap(id),
                      ),
              ),
              // Floating top panel + stats + mode banner (DESIGN §3)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            MapRoundButton(
                              icon: Icons.menu_rounded,
                              tooltip: 'Menyu',
                              onPressed: () =>
                                  _scaffoldKey.currentState?.openDrawer(),
                            ),
                            const SizedBox(width: 10),
                            const _BrandPill(),
                            const Spacer(),
                            MapRoundButton(
                              icon: Icons.search_rounded,
                              tooltip: 'Qidirish',
                              onPressed: _openSearch,
                            ),
                            const SizedBox(width: 10),
                            MapRoundButton(
                              icon: mapLayer == MapLayer.scheme
                                  ? Icons.layers_outlined
                                  : Icons.satellite_alt_outlined,
                              tooltip: 'Xarita ko\'rinishi',
                              onPressed: () => showModalBottomSheet<void>(
                                context: context,
                                builder: (_) => const MapStyleSheet(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            MapRoundButton(
                              icon: Icons.tune_rounded,
                              tooltip: 'Holat filtri',
                              badge:
                                  activeStatuses.length <
                                      WorkStatus.values.length
                                  ? activeStatuses.length
                                  : null,
                              onPressed: () {
                                showModalBottomSheet<void>(
                                  context: context,
                                  builder: (_) => const FilterSheet(),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween(
                                    begin: const Offset(0, -0.25),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                          child: mapState.mode.bannerText != null
                              ? _ModeBannerCard(
                                  key: ValueKey(mapState.mode.runtimeType),
                                  mode: mapState.mode,
                                  savingMove: _savingMove,
                                  onSaveMove: mapState.mode is MoveManholeMode
                                      ? () => _saveMoveManhole(
                                          mapState.mode as MoveManholeMode,
                                        )
                                      : null,
                                  onCancel: () => ref
                                      .read(mapControllerProvider.notifier)
                                      .cancelMode(),
                                )
                              : traceId != null &&
                                    timeline == null &&
                                    allManholes[traceId] != null
                              ? TraceLegendCard(
                                  key: ValueKey('trace_$traceId'),
                                  origin: allManholes[traceId]!,
                                  trace: NetworkGraph.trace(
                                    traceId,
                                    allPipes.values,
                                  ),
                                  pipes: allPipes,
                                  manholes: allManholes,
                                  onClose: () => ref
                                      .read(traceProvider.notifier)
                                      .clear(),
                                )
                              : NetworkStatsCard(
                                  key: const ValueKey('stats'),
                                  stats: NetworkStats.from(
                                    net.manholes.values,
                                    net.pipes.values,
                                  ),
                                ),
                        ),
                        if (isOffline)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Chip(
                                avatar: const Icon(
                                  Icons.cloud_off_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Ulanish yo\'q',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                backgroundColor: AppColors.danger,
                                side: BorderSide.none,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (mapState.mode is AddPipeMode &&
                  (mapState.mode as AddPipeMode).fromManholeId != null)
                Positioned.fill(
                  child: RubberBandOverlay(
                    info: _rubberInfo,
                    onConnect: (id) => ref
                        .read(mapControllerProvider.notifier)
                        .onManholeTap(id, existingPipes: allPipes.values),
                  ),
                ),
              if (timeline != null)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: SafeArea(
                    top: false,
                    child: TimelinePanel(
                      timeline: timeline,
                      completedMeters: NetworkStats.from(
                        net.manholes.values,
                        net.pipes.values,
                      ).meters[WorkStatus.completed]!,
                      totalMeters: NetworkStats.from(
                        allManholes.values,
                        allPipes.values,
                      ).totalMeters,
                    ),
                  ),
                ),
              // Bottom-right: my location + admin speed dial
              if (mapState.activeForm == null && timeline == null)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        MapRoundButton(
                          icon: Icons.my_location_rounded,
                          tooltip: 'Mening joylashuvim',
                          onPressed: _locatingGps ? null : _jumpToMyLocation,
                          child: _locatingGps
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : null,
                        ),
                        if (isAdmin && mapState.mode is ViewMode) ...[
                          const SizedBox(height: 14),
                          SpeedDial(
                            actions: [
                              SpeedDialAction(
                                icon: Icons.timeline_rounded,
                                label: 'Quvur',
                                onPressed: () => ref
                                    .read(mapControllerProvider.notifier)
                                    .startAddPipe(isAdmin: isAdmin),
                              ),
                              SpeedDialAction(
                                icon: Icons.add_location_alt_outlined,
                                label: 'Kolodets',
                                onPressed: () => ref
                                    .read(mapControllerProvider.notifier)
                                    .startAddManhole(isAdmin: isAdmin),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TuronNavigationDrawer extends StatelessWidget {
  final bool isAdmin;
  final String? fullName;
  final Future<void> Function() onSignOut;
  final VoidCallback onTimeline;
  final Future<void> Function() onReport;

  const _TuronNavigationDrawer({
    required this.isAdmin,
    required this.fullName,
    required this.onSignOut,
    required this.onTimeline,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final destinations = <({String label, IconData icon, String? route})>[
      (label: 'Xarita', icon: Icons.map_outlined, route: null),
      (
        label: 'Qurilish taymlayni',
        icon: Icons.history_rounded,
        route: '__timeline__',
      ),
      (
        label: 'Hisobot (PDF)',
        icon: Icons.picture_as_pdf_outlined,
        route: '__report__',
      ),
      if (isAdmin) ...[
        (
          label: 'Foydalanuvchilar',
          icon: Icons.group_outlined,
          route: '/admin/users',
        ),
        (
          label: 'Ustalar',
          icon: Icons.engineering_outlined,
          route: '/admin/masters',
        ),
      ],
      (label: 'Profil', icon: Icons.person_outline, route: '/profile'),
      (label: 'Chiqish', icon: Icons.logout, route: '__logout__'),
    ];

    return NavigationDrawer(
      selectedIndex: 0,
      onDestinationSelected: (index) async {
        final item = destinations[index];
        Navigator.of(context).pop();
        if (item.route == null) {
          return;
        }
        if (item.route == '__logout__') {
          await onSignOut();
          return;
        }
        if (item.route == '__timeline__') {
          onTimeline();
          return;
        }
        if (item.route == '__report__') {
          await onReport();
          return;
        }
        if (context.mounted) {
          context.push(item.route!);
        }
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Turon — Kanalizatsiya GIS',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (fullName != null && fullName!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  fullName!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(indent: 28, endIndent: 28),
        for (final item in destinations)
          NavigationDrawerDestination(
            icon: Icon(item.icon),
            label: Text(item.label),
          ),
      ],
    );
  }
}

class _BrandPill extends StatelessWidget {
  const _BrandPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        boxShadow: AppShadows.floating,
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.water_drop_rounded, color: AppColors.brand, size: 20),
          SizedBox(width: 6),
          Text(
            'Turon',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              letterSpacing: -0.3,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeBannerCard extends StatelessWidget {
  final MapMode mode;
  final bool savingMove;
  final VoidCallback? onSaveMove;
  final VoidCallback onCancel;

  const _ModeBannerCard({
    super.key,
    required this.mode,
    required this.savingMove,
    required this.onSaveMove,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final bannerText = mode.bannerText ?? '';
    final moveMode = mode is MoveManholeMode ? mode as MoveManholeMode : null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: AppShadows.floating,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.touch_app_rounded,
                  size: 20,
                  color: AppColors.brandSoft,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    moveMode != null
                        ? '$bannerText (${moveMode.newLat.toStringAsFixed(5)}, ${moveMode.newLng.toStringAsFixed(5)})'
                        : bannerText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onSaveMove != null) ...[
                  FilledButton.icon(
                    onPressed: savingMove ? null : onSaveMove,
                    icon: savingMove
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check, size: 16),
                    label: const Text('Saqlash'),
                  ),
                  const SizedBox(width: 8),
                ],
                TextButton(
                  onPressed: savingMove ? null : onCancel,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.brandSoft,
                  ),
                  child: const Text('Bekor qilish'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Fallback interactive canvas used in widget tests or when YANDEX_MAPKIT_KEY is empty.
class _MapPlaceholderCanvas extends StatelessWidget {
  final List<Manhole> manholes;
  final Map<String, Manhole> allManholes;
  final List<Pipe> pipes;
  final Selection? selection;
  final MapMode mode;
  final void Function(double lat, double lng) onMapTap;
  final void Function(String manholeId) onManholeTap;
  final void Function(String pipeId) onPipeTap;

  const _MapPlaceholderCanvas({
    required this.manholes,
    required this.allManholes,
    required this.pipes,
    required this.selection,
    required this.mode,
    required this.onMapTap,
    required this.onManholeTap,
    required this.onPipeTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (_) => onMapTap(GeoUtils.qarshiLat, GeoUtils.qarshiLng),
      child: Container(
        color: const Color(0xFFE8EEF3),
        padding: const EdgeInsets.fromLTRB(16, 72, 16, 72),
        child: ListView(
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...manholes.map((m) {
                  final selected =
                      selection is ManholeSelection &&
                      (selection as ManholeSelection).id == m.id;
                  return ActionChip(
                    avatar: CircleAvatar(
                      backgroundColor: AppColors.forStatus(m.status),
                    ),
                    backgroundColor: selected ? Colors.blue.shade100 : null,
                    label: Text(m.code),
                    onPressed: () => onManholeTap(m.id),
                  );
                }),
                ...pipes.map((p) {
                  final selected =
                      selection is PipeSelection &&
                      (selection as PipeSelection).id == p.id;
                  final from = allManholes[p.fromManholeId]?.code ?? '?';
                  final to = allManholes[p.toManholeId]?.code ?? '?';
                  return ActionChip(
                    avatar: Icon(
                      Icons.timeline,
                      size: 16,
                      color: AppColors.forStatus(p.status),
                    ),
                    backgroundColor: selected ? Colors.blue.shade100 : null,
                    label: Text('${p.code} ($from\u2192$to)'),
                    onPressed: () => onPipeTap(p.id),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
