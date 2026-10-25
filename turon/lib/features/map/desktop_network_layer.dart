import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:yandex_map_desktop/yandex_map_desktop.dart' as ymd;

import '../../core/geo_utils.dart';
import '../../core/theme.dart';
import '../../data/models/manhole.dart';
import '../../data/models/pipe.dart';
import '../../data/models/work_status.dart';
import 'map_mode.dart';
import 'map_objects_layer.dart';
import 'network_graph.dart';
import 'network_layer.dart';

/// Windows/macOS implementation of [NetworkLayer] on the Yandex JS API
/// (`yandex_map_desktop`). Looks like the MapKit layer: manhole covers
/// (same bitmaps, code as HTML text), casing + status-coloured pipes
/// (planned dashed), direction arrows, length pills, pulse halos, flow
/// trace glow, rubber band and the construction replay.
///
/// Only changed objects are sent to the WebView.
class DesktopNetworkLayer implements NetworkLayer {
  final ymd.YandexMapDesktopController controller;
  final void Function(String manholeId) onManholeTap;
  final void Function(String pipeId) onPipeTap;
  final void Function(double lat, double lng) onManholeMoved;

  DesktopNetworkLayer({
    required this.controller,
    required this.onManholeTap,
    required this.onPipeTap,
    required this.onManholeMoved,
  }) {
    _ready = _defineIcons();
  }

  @override
  bool animationsEnabled = true;

  @override
  bool highContrast = false;

  // Pulses run as CSS animations inside the WebView; nothing to tick.
  @override
  bool get hasActiveAnimations => false;

  @override
  void tick() {}

  // ── Inputs of the last sync ────────────────────────────────────────────
  Map<String, Manhole> _manholes = const {};
  Map<String, Pipe> _pipes = const {};
  Set<WorkStatus> _statuses = WorkStatus.values.toSet();
  Selection? _selection;
  MapMode _mode = const ViewMode();
  double _zoom = 14;
  FlowTrace? _trace;
  Set<String> _hidden = const {};

  // ── WebView state ──────────────────────────────────────────────────────
  late final Future<void> _ready;
  bool _isReady = false;
  final Map<String, String> _sent = {}; // object id -> last spec (json)
  final Map<String, ({double w, double h})> _iconSize = {};
  String? _draggingId;

  String? _buildId;
  bool _buildIsPipe = false;
  double _buildT = 1;
  ({({double lat, double lng}) from, ({double lat, double lng}) to, bool snapped})?
  _rubber;

  // ── Icons (drawn once, same painters as Android) ───────────────────────
  static double get _dpr =>
      (ui.PlatformDispatcher.instance.views.firstOrNull?.devicePixelRatio ??
              2.0)
          .clamp(2.0, 3.5);

  static String _manholeIcon(WorkStatus s, bool selected, String bucket) =>
      'mh_${s.name}_${selected ? 'sel' : 'norm'}_$bucket';
  static String _arrowIcon(WorkStatus s, bool selected) =>
      'ar_${s.name}_${selected ? 'sel' : 'norm'}';
  static String _haloIcon(String bucket) => 'halo_$bucket';

  Future<void> _defineIcons() async {
    final icons = <String, String>{};
    Future<void> add(String key, Future<ui.Image> image, double dpr) async {
      final img = await image;
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      _iconSize[key] = (w: img.width / dpr, h: img.height / dpr);
      icons[key] =
          'data:image/png;base64,${base64Encode(bytes!.buffer.asUint8List())}';
      img.dispose();
    }

    for (final s in WorkStatus.values) {
      for (final sel in [false, true]) {
        for (final bucket in ['dot', 'full']) {
          await add(
            _manholeIcon(s, sel, bucket),
            MapObjectsLayerController.drawManholeImage(
              ManholeMarkerCacheKey(
                status: s,
                code: '', // the code is HTML text on desktop
                selected: sel,
                zoomBucket: bucket,
              ),
              dprOverride: 2.0,
            ),
            2.0,
          );
        }
        await add(
          _arrowIcon(s, sel),
          MapObjectsLayerController.drawArrowImage(AppColors.forStatus(s), sel),
          _dpr,
        );
      }
    }
    for (final bucket in ['dot', 'full']) {
      await add(
        _haloIcon(bucket),
        MapObjectsLayerController.drawHaloImage(bucket == 'dot' ? 16.0 : 40.0),
        _dpr,
      );
    }
    await controller.defineIcons(icons);
    _isReady = true;
    _flush();
  }

  // ── NetworkLayer ───────────────────────────────────────────────────────
  @override
  void sync({
    required Map<String, Manhole> allManholes,
    required Map<String, Pipe> allPipes,
    required Set<WorkStatus> activeStatuses,
    required Selection? selection,
    required MapMode mode,
    required double zoom,
    FlowTrace? trace,
    Set<String> hiddenManholeIds = const {},
  }) {
    _manholes = allManholes;
    _pipes = allPipes;
    _statuses = activeStatuses;
    _selection = selection;
    _mode = mode;
    _zoom = zoom;
    _trace = trace;
    _hidden = hiddenManholeIds;
    _flush();
  }

  @override
  void restylePipes() => _flush();

  @override
  void setRubberBand(
    ({double lat, double lng})? from,
    ({double lat, double lng})? to, {
    bool snapped = false,
  }) {
    _rubber = from == null || to == null
        ? null
        : (from: from, to: to, snapped: snapped);
    if (!_isReady) return;
    final spec = _rubberSpec();
    if (spec == null) {
      _send(const [], ['_rubber']);
    } else {
      _send([spec], const []);
    }
  }

  @override
  void setBuildProgress(String? id, {bool isPipe = false, double t = 1}) {
    final previous = _buildId;
    final previousIsPipe = _buildIsPipe;
    _buildId = id;
    _buildIsPipe = isPipe;
    _buildT = t.clamp(0.0, 1.0);
    if (!_isReady) return;
    // Only the objects involved in the animation are re-sent each frame.
    final ids = <String>{
      if (previous != null && previous != id) ...[
        previousIsPipe ? 'p:$previous' : 'm:$previous',
        if (previousIsPipe) 'a:$previous',
      ],
      if (id != null) ...[
        isPipe ? 'p:$id' : 'm:$id',
        if (isPipe) 'a:$id',
      ],
      '_ghost',
    };
    final specs = _allSpecs();
    _send(
      [
        for (final key in ids)
          if (specs[key] != null) specs[key]!,
      ],
      [
        for (final key in ids)
          if (specs[key] == null) key,
      ],
    );
  }

  // ── Spec building ──────────────────────────────────────────────────────
  void _flush() {
    if (!_isReady) return;
    final specs = _allSpecs();
    final upserts = <Map<String, Object?>>[];
    for (final e in specs.entries) {
      if (e.key == _draggingId) continue; // the WebView owns it while dragging
      upserts.add(e.value);
    }
    final removes = [
      for (final id in _sent.keys)
        if (!specs.containsKey(id)) id,
    ];
    _send(upserts, removes);
  }

  /// Sends specs that differ from what the WebView already has.
  void _send(List<Map<String, Object?>> specs, List<String> removes) {
    final changed = <Map<String, Object?>>[];
    for (final spec in specs) {
      final id = spec['id']! as String;
      final json = jsonEncode(spec);
      if (_sent[id] == json) continue;
      _sent[id] = json;
      changed.add(spec);
    }
    final gone = [
      for (final id in removes)
        if (_sent.remove(id) != null) id,
    ];
    if (gone.isNotEmpty) controller.remove(gone);
    if (changed.isNotEmpty) controller.upsert(changed);
  }

  Map<String, Map<String, Object?>> _allSpecs() {
    final specs = <String, Map<String, Object?>>{};
    final movingId = _mode is MoveManholeMode
        ? (_mode as MoveManholeMode).manholeId
        : null;
    final bucket = MapObjectsLayer.zoomBucket(_zoom);
    final showLabels = _zoom >= MapObjectsLayer.pipeLabelMinZoom;

    ({double lat, double lng}) posOf(Manhole m) {
      final mode = _mode;
      if (mode is MoveManholeMode && mode.manholeId == m.id) {
        return (lat: mode.newLat, lng: mode.newLng);
      }
      return (lat: m.lat, lng: m.lng);
    }

    // Manholes.
    for (final m in MapObjectsLayer.filterManholes(
      _manholes,
      _statuses,
      forceIncludeManholeId: movingId,
    )) {
      if (_hidden.contains(m.id)) continue;
      final p = posOf(m);
      final selected =
          (_selection is ManholeSelection &&
              (_selection as ManholeSelection).id == m.id) ||
          (_mode is AddPipeMode &&
              ((_mode as AddPipeMode).fromManholeId == m.id ||
                  (_mode as AddPipeMode).toManholeId == m.id)) ||
          movingId == m.id;
      final key = _manholeIcon(m.status, selected, bucket);
      final size = _iconSize[key]!;
      final building = !_buildIsPipe && _buildId == m.id;
      specs['m:${m.id}'] = {
        'id': 'm:${m.id}',
        'type': 'image',
        'lat': p.lat,
        'lng': p.lng,
        'icon': key,
        'w': size.w,
        'h': size.h,
        'txt': bucket == 'full' ? m.code : '',
        'fs': selected ? 12 : 11,
        'sc': building
            ? math.max(0.01, Curves.easeOutBack.transform(_buildT))
            : 1,
        'z': building ? 25 : (selected ? 20 : 10),
        'drag': movingId == m.id,
        'hint': m.code,
      };
      if (animationsEnabled && m.status == WorkStatus.inProgress) {
        final halo = _haloIcon(bucket);
        final hs = _iconSize[halo]!;
        specs['h:${m.id}'] = {
          'id': 'h:${m.id}',
          'type': 'image',
          'lat': p.lat,
          'lng': p.lng,
          'icon': halo,
          'w': hs.w,
          'h': hs.h,
          'cls': 'ymd-pulse',
          'z': 9,
        };
      }
    }

    // Pipes.
    final traced = {...?_trace?.downstreamPipes, ...?_trace?.upstreamPipes};
    for (final pipe in MapObjectsLayer.filterPipes(
      _pipes,
      _statuses,
      allManholes: _manholes,
    )) {
      final a = posOf(_manholes[pipe.fromManholeId]!);
      final b = posOf(_manholes[pipe.toManholeId]!);
      final coords = [
        a,
        for (final v in pipe.path) (lat: v[0], lng: v[1]),
        b,
      ];
      final selected =
          _selection is PipeSelection &&
          (_selection as PipeSelection).id == pipe.id;
      final building = _buildIsPipe && _buildId == pipe.id;
      final width =
          MapObjectsLayer.pipeWidthForDiameter(pipe.diameterMm) +
          (selected ? 2 : 0) +
          (highContrast ? 2 : 0);
      final color = AppColors.forStatus(pipe.status);
      final planned = pipe.status == WorkStatus.planned;
      final traceColor = _trace?.downstreamPipes.contains(pipe.id) ?? false
          ? MapObjectsLayer.traceDownColor
          : MapObjectsLayer.traceUpColor;
      final flowing =
          animationsEnabled &&
          (selected ||
              traced.contains(pipe.id) ||
              pipe.status == WorkStatus.inProgress);
      final shown = building ? _partial(coords, _buildT) : coords;
      specs['p:${pipe.id}'] = {
        'id': 'p:${pipe.id}',
        'type': 'polyline',
        'points': [
          for (final c in shown) [c.lat, c.lng],
        ],
        'strokes': [
          if (traced.contains(pipe.id))
            {'c': _hex(traceColor, 0.32), 'w': width + 12},
          {
            'c': selected ? _hex(AppColors.brand, 0.45) : '#FFFFFFFF',
            'w': width + (selected ? 6 : (highContrast ? 5 : 4)),
          },
          {'c': _hex(color), 'w': width, 's': planned ? 'dash' : 'solid'},
          if (flowing)
            {
              'c': '#FFFFFFE6',
              'w': math.max(2.0, width * 0.45),
              's': 'shortdash',
            },
        ],
        'z': building ? 6 : (selected ? 5 : 1),
        'hint': pipe.code,
      };
      if (!building) {
        final mid = GeoUtils.alongPolyline(coords, 0.5);
        final ak = _arrowIcon(pipe.status, selected);
        final as = _iconSize[ak]!;
        specs['a:${pipe.id}'] = {
          'id': 'a:${pipe.id}',
          'type': 'image',
          'lat': mid.lat,
          'lng': mid.lng,
          'icon': ak,
          'w': as.w,
          'h': as.h,
          'rot': mid.bearing,
          'z': selected ? 8 : 3,
        };
        if (showLabels) {
          specs['l:${pipe.id}'] = {
            'id': 'l:${pipe.id}',
            'type': 'pill',
            'lat': mid.lat,
            'lng': mid.lng,
            'txt':
                '${GeoUtils.formatLength(pipe.lengthM)} · Ø${pipe.diameterMm}',
            'z': 4,
          };
        }
      } else {
        // Grey "planned" ghost under the growing pipe.
        specs['_ghost'] = {
          'id': '_ghost',
          'type': 'polyline',
          'points': [
            for (final c in coords) [c.lat, c.lng],
          ],
          'strokes': [
            {'c': '#FFFFFFFF', 'w': width + 4},
            {'c': _hex(AppColors.planned, 0.7), 'w': width, 's': 'dash'},
          ],
          'z': 0,
        };
      }
    }

    final rubber = _rubberSpec();
    if (rubber != null) specs['_rubber'] = rubber;
    return specs;
  }

  Map<String, Object?>? _rubberSpec() {
    final r = _rubber;
    if (r == null) return null;
    return {
      'id': '_rubber',
      'type': 'polyline',
      'points': [
        [r.from.lat, r.from.lng],
        [r.to.lat, r.to.lng],
      ],
      'strokes': [
        {'c': '#FFFFFFFF', 'w': r.snapped ? 9 : 7.5},
        {
          'c': _hex(r.snapped ? AppColors.brand : AppColors.ink),
          'w': r.snapped ? 5 : 3.5,
          's': r.snapped ? 'solid' : 'dash',
        },
      ],
      'z': 30,
    };
  }

  // ── Events from the WebView ────────────────────────────────────────────
  void handleObjectTap(String id) {
    if (id.startsWith('m:')) {
      onManholeTap(id.substring(2));
    } else if (id.startsWith('p:') ||
        id.startsWith('a:') ||
        id.startsWith('l:')) {
      onPipeTap(id.substring(2));
    }
  }

  void handleObjectDrag(String id, double lat, double lng, {bool end = false}) {
    if (!id.startsWith('m:')) return;
    _draggingId = end ? null : id;
    onManholeMoved(lat, lng);
  }

  // ── Helpers ────────────────────────────────────────────────────────────
  static String _hex(Color c, [double alpha = 1]) {
    int ch(double v) => (v * 255).round().clamp(0, 255);
    String h(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
    return '#${h(ch(c.r))}${h(ch(c.g))}${h(ch(c.b))}${h(ch(alpha * c.a))}';
  }

  static List<({double lat, double lng})> _partial(
    List<({double lat, double lng})> pts,
    double t,
  ) {
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
    final target = total * t;
    final out = [pts.first];
    var acc = 0.0;
    for (var i = 0; i < lengths.length; i++) {
      if (acc + lengths[i] >= target) {
        final k = lengths[i] == 0 ? 0.0 : (target - acc) / lengths[i];
        out.add((
          lat: pts[i].lat + (pts[i + 1].lat - pts[i].lat) * k,
          lng: pts[i].lng + (pts[i + 1].lng - pts[i].lng) * k,
        ));
        return out;
      }
      acc += lengths[i];
      out.add(pts[i + 1]);
    }
    return out;
  }

  /// Completes when the icons are registered in the WebView.
  Future<void> get ready => _ready;
}
