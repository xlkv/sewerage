import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart' as wf;
import 'package:webview_windows/webview_windows.dart' as ww;

import '_html_builder.dart';
import 'controller.dart';
import 'map_objects.dart';
import 'types.dart';

/// A Flutter widget that embeds Yandex Maps (JavaScript API 2.1) inside a
/// platform WebView.
///
/// * **Windows** – uses [webview_windows] (Chromium/WebView2).
/// * **macOS**   – uses [webview_flutter] (WKWebView).
///
/// ### Quick start
/// ```dart
/// YandexMapDesktop(
///   apiKey: 'YOUR_KEY',
///   initialCameraPosition: CameraPosition(
///     target: Point(latitude: 55.755864, longitude: 37.617698),
///     zoom: 12,
///   ),
///   onMapCreated: (controller) { ... },
/// )
/// ```
///
/// ### Yandex Maps API key
/// Get yours at https://developer.tech.yandex.com (enable
/// "JavaScript API and HTTP Geocoder") and set domain restrictions to
/// "Without restrictions" so the key works from a local WebView origin.
class YandexMapDesktop extends StatefulWidget {
  /// Yandex Maps JavaScript API key.
  final String apiKey;

  /// Where the camera should point when the map first opens.
  final CameraPosition initialCameraPosition;

  /// List of [MapObject]s (placemarks, polylines …) to render on the map.
  ///
  /// Pass a new list (or call [setState]) to update the displayed objects;
  /// the widget reconciles the change automatically.
  final List<MapObject> mapObjects;

  /// Called once the map has fully initialised and is ready to accept
  /// programmatic camera and object commands.
  final void Function(YandexMapDesktopController controller)? onMapCreated;

  /// Called when the user taps the map background.
  final void Function(Point point)? onMapTap;

  /// Called when the user right-clicks / long-presses the map background.
  final void Function(Point point)? onMapLongTap;

  /// Called whenever the camera position changes.
  ///
  /// [finished] is `true` when the movement has ended (i.e. after the
  /// `actionend` event); `false` while the camera is still animating.
  final void Function(CameraPosition position, bool finished)?
      onCameraPositionChanged;

  /// Tap on an object added with the imperative API
  /// ([YandexMapDesktopController.upsert]).
  final void Function(String id, Point point)? onObjectTap;

  /// A draggable image object is being dragged / was dropped.
  final void Function(String id, Point point)? onObjectDrag;
  final void Function(String id, Point point)? onObjectDragEnd;

  /// The user started moving the map (drag or wheel), as opposed to a
  /// programmatic camera move.
  final VoidCallback? onUserAction;

  /// Map language, e.g. `ru_RU`, `uz_UZ`, `en_US`.
  final String lang;

  /// Built-in Yandex controls to show, e.g. `['zoomControl']`.
  final List<String> controls;

  const YandexMapDesktop({
    super.key,
    required this.apiKey,
    this.initialCameraPosition = const CameraPosition(
      target: Point(latitude: 55.755864, longitude: 37.617698), // Moscow
    ),
    this.mapObjects = const [],
    this.onMapCreated,
    this.onMapTap,
    this.onMapLongTap,
    this.onCameraPositionChanged,
    this.onObjectTap,
    this.onObjectDrag,
    this.onObjectDragEnd,
    this.onUserAction,
    this.lang = 'ru_RU',
    this.controls = const [],
  });

  @override
  State<YandexMapDesktop> createState() => _YandexMapDesktopState();
}

// =============================================================================

class _YandexMapDesktopState extends State<YandexMapDesktop> {
  // WebView controllers – only one is used depending on the platform.
  ww.WebviewController? _wwController; // Windows
  wf.WebViewController? _wfController; // macOS

  // Windows-only: subscription to the webMessage stream.
  StreamSubscription<dynamic>? _subscription;

  bool _mapReady = false;
  String? _initError;
  YandexMapDesktopController? _controller;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(YandexMapDesktop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_mapReady &&
        widget.mapObjects != oldWidget.mapObjects &&
        (widget.mapObjects.isNotEmpty || oldWidget.mapObjects.isNotEmpty)) {
      _pushObjects();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _wwController?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  Future<void> _init() async {
    final html = buildMapHtml(
      widget.apiKey,
      lat: widget.initialCameraPosition.target.latitude,
      lng: widget.initialCameraPosition.target.longitude,
      zoom: widget.initialCameraPosition.zoom,
      lang: widget.lang,
      controls: widget.controls,
    );

    try {
      if (Platform.isWindows) {
        await _initWindows(html);
      } else {
        _initMacOS(html);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _initError = e.toString());
      }
    }
  }

  Future<void> _initWindows(String html) async {
    final ctrl = ww.WebviewController();
    await ctrl.initialize();
    _subscription = ctrl.webMessage.listen(
      (dynamic msg) => _handleMessage(msg.toString()),
      onError: (Object err) {
        debugPrint('YandexMapDesktop [windows]: webMessage error: $err');
      },
    );
    await ctrl.loadStringContent(html);
    if (mounted) setState(() => _wwController = ctrl);
  }

  void _initMacOS(String html) {
    _wfController = wf.WebViewController()
      ..setJavaScriptMode(wf.JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (wf.JavaScriptMessage msg) =>
            _handleMessage(msg.message),
      )
      ..loadHtmlString(html);
  }

  // ---------------------------------------------------------------------------
  // JavaScript bridge
  // ---------------------------------------------------------------------------

  Future<void> _js(String code) async {
    try {
      if (Platform.isWindows) {
        await _wwController?.executeScript(code);
      } else {
        await _wfController?.runJavaScript(code);
      }
    } catch (e) {
      debugPrint('YandexMapDesktop: JS error: $e');
    }
  }

  /// Declarative API: replaces all objects with [YandexMapDesktop.mapObjects].
  /// (Apps using the imperative controller API leave `mapObjects` empty.)
  void _pushObjects() {
    if (widget.mapObjects.isEmpty) return;
    final payload = jsonEncode(
      widget.mapObjects.map(_serializeObject).toList(),
    ).replaceAll('\u2028', r'\u2028').replaceAll('\u2029', r'\u2029');
    _js('window.setObjects($payload)');
  }

  // ---------------------------------------------------------------------------
  // Message handling
  // ---------------------------------------------------------------------------

  void _handleMessage(String raw) {
    try {
      final msg = jsonDecode(raw) as Map<String, dynamic>;
      final type = msg['type'] as String;

      switch (type) {
        // ---- Map ready ----
        case 'ready':
          final ctrl = YandexMapDesktopController(
            initialPosition: widget.initialCameraPosition,
            runJs: _js,
          );
          _controller = ctrl;
          if (mounted) setState(() => _mapReady = true);
          widget.onMapCreated?.call(ctrl);
          _pushObjects();

        // ---- Map background taps ----
        case 'mapTap':
          widget.onMapTap?.call(_pointFromMsg(msg));

        case 'mapLongTap':
          widget.onMapLongTap?.call(_pointFromMsg(msg));

        // ---- Camera change ----
        case 'cameraChange':
          final pos = CameraPosition(
            target: _pointFromMsg(msg),
            zoom: (msg['zoom'] as num).toDouble(),
          );
          _controller?.updatePosition(pos);
          widget.onCameraPositionChanged?.call(pos, msg['finished'] as bool);

        case 'userAction':
          widget.onUserAction?.call();

        case 'objectDrag':
          widget.onObjectDrag?.call(msg['id'] as String, _pointFromMsg(msg));

        case 'objectDragEnd':
          widget.onObjectDragEnd?.call(msg['id'] as String, _pointFromMsg(msg));

        // ---- Object tap ----
        case 'objectTap':
          final id = msg['id'] as String;
          final tappedPoint = _pointFromMsg(msg);
          widget.onObjectTap?.call(id, tappedPoint);
          for (final obj in widget.mapObjects) {
            if (obj.mapId.value == id) {
              if (obj is PlacemarkMapObject) {
                obj.onTap?.call(obj, tappedPoint);
              } else if (obj is PolylineMapObject) {
                obj.onTap?.call(obj);
              }
              break;
            }
          }
      }
    } catch (e) {
      debugPrint('YandexMapDesktop: message parse error: $e  raw=$raw');
    }
  }

  static Point _pointFromMsg(Map<String, dynamic> msg) => Point(
        latitude: (msg['lat'] as num).toDouble(),
        longitude: (msg['lng'] as num).toDouble(),
      );

  // ---------------------------------------------------------------------------
  // Serialisation helpers
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _serializeObject(MapObject obj) {
    if (obj is PlacemarkMapObject) {
      return {
        'id': obj.mapId.value,
        'type': 'placemark',
        'lat': obj.point.latitude,
        'lng': obj.point.longitude,
        'color': _colorToHex(obj.icon.color),
        'size': obj.icon.size,
        'label': obj.label,
        'opacity': obj.opacity,
      };
    } else if (obj is PolylineMapObject) {
      return {
        'id': obj.mapId.value,
        'type': 'polyline',
        'points': obj.coordinates
            .map((p) => {'lat': p.latitude, 'lng': p.longitude})
            .toList(),
        'strokeColor': _colorToHex(obj.strokeColor),
        'strokeWidth': obj.strokeWidth,
        'opacity': obj.opacity,
      };
    }
    throw UnsupportedError(
      'YandexMapDesktop: unsupported MapObject type: ${obj.runtimeType}',
    );
  }

  /// Converts a [Color] to a CSS hex string `#RRGGBB` (alpha is dropped).
  static String _colorToHex(Color color) {
    int ch(double c) => (c * 255).round().clamp(0, 255);
    return '#'
        '${ch(color.r).toRadixString(16).padLeft(2, '0')}'
        '${ch(color.g).toRadixString(16).padLeft(2, '0')}'
        '${ch(color.b).toRadixString(16).padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return _ErrorView(error: _initError!);
    }

    if (!_mapReady) {
      return const Center(child: CircularProgressIndicator());
    }

    if (Platform.isWindows) {
      return ww.Webview(_wwController!);
    } else {
      return wf.WebViewWidget(controller: _wfController!);
    }
  }
}

// =============================================================================
// Error overlay
// =============================================================================

class _ErrorView extends StatelessWidget {
  final String error;
  const _ErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFFFEBEE), // Colors.red.shade50
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFC62828), size: 48),
            const SizedBox(height: 12),
            const Text(
              'YandexMapDesktop failed to initialise',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFFC62828),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(fontSize: 12, color: Color(0xFF757575)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
