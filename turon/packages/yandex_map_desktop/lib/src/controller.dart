import 'dart:convert';

import 'types.dart';

/// Base map look for [YandexMapDesktopController.setMapType].
enum DesktopMapType {
  map('yandex#map'),
  satellite('yandex#satellite'),
  hybrid('yandex#hybrid');

  final String jsName;
  const DesktopMapType(this.jsName);
}

/// Controls a [YandexMapDesktop] widget programmatically.
///
/// An instance is delivered to you via [YandexMapDesktop.onMapCreated] after
/// the map has fully initialised.
class YandexMapDesktopController {
  /// Most-recently known camera position (updated by the widget on every
  /// `cameraChange` event received from the WebView).
  CameraPosition _cameraPosition;

  /// Internal callback that executes arbitrary JavaScript inside the WebView.
  final Future<void> Function(String jsCode) _runJs;

  /// Internal constructor – called exclusively by [YandexMapDesktop].
  ///
  /// Do **not** call this constructor from application code.
  YandexMapDesktopController({
    required CameraPosition initialPosition,
    required Future<void> Function(String) runJs,
  })  : _cameraPosition = initialPosition,
        _runJs = runJs;

  /// Updates the tracked camera position.
  ///
  /// This is called by [YandexMapDesktop] on every `cameraChange` event.
  void updatePosition(CameraPosition pos) => _cameraPosition = pos;

  /// Returns the last known camera position.
  CameraPosition getCameraPosition() => _cameraPosition;

  /// Moves the camera according to [update], animated over [duration]
  /// (`Duration.zero` = jump).
  Future<void> moveCamera(
    CameraUpdate update, {
    Duration duration = const Duration(milliseconds: 300),
  }) async {
    final c = _cameraPosition;
    final ({double lat, double lng, double? zoom}) target;
    if (update is LatLngCameraUpdate) {
      target = (
        lat: update.point.latitude,
        lng: update.point.longitude,
        zoom: update.zoom,
      );
    } else if (update is PositionCameraUpdate) {
      target = (
        lat: update.position.target.latitude,
        lng: update.position.target.longitude,
        zoom: update.position.zoom,
      );
    } else if (update is ZoomCameraUpdate) {
      target = (
        lat: c.target.latitude,
        lng: c.target.longitude,
        zoom: update.zoom,
      );
    } else if (update is ZoomDeltaCameraUpdate) {
      target = (
        lat: c.target.latitude,
        lng: c.target.longitude,
        zoom: c.zoom + update.delta,
      );
    } else {
      return;
    }
    await _call('moveCamera', {
      'lat': target.lat,
      'lng': target.lng,
      if (target.zoom != null) 'zoom': target.zoom,
      'duration': duration.inMilliseconds,
    });
  }

  // ---------------------------------------------------------------------------
  // Imperative object API (efficient for many objects)

  /// Registers reusable icon images: key -> data URI (`data:image/png;...`).
  /// Image items reference them with `'icon': key`.
  Future<void> defineIcons(Map<String, String> icons) =>
      _call('defineIcons', icons);

  /// Adds or updates objects by `id`. Supported items:
  ///
  /// * `{'id', 'type': 'image', 'lat', 'lng', 'icon' | 'href', 'w', 'h',
  ///   'ax', 'ay' (anchor 0..1), 'rot' (deg), 'sc' (scale), 'op',
  ///   'z' (z-index), 'drag', 'txt' (centred label), 'fs' (font px),
  ///   'cls' (CSS class, e.g. 'ymd-pulse'), 'hint'}`
  /// * `{'id', 'type': 'pill', 'lat', 'lng', 'txt', 'z'}` – text pill
  ///   below the point.
  /// * `{'id', 'type': 'polyline', 'points': [[lat, lng], ...],
  ///   'strokes': [{'c': '#RRGGBBAA', 'w': 4, 's': 'solid'|'dash'}, ...],
  ///   'op', 'z', 'hint'}` – strokes are drawn bottom to top.
  Future<void> upsert(List<Map<String, Object?>> items) =>
      items.isEmpty ? Future.value() : _call('upsert', items);

  /// Removes objects by id.
  Future<void> remove(List<String> ids) =>
      ids.isEmpty ? Future.value() : _call('remove', ids);

  Future<void> setMapType(DesktopMapType type) =>
      _call('setMapType', type.jsName);

  /// CSS filter applied to the base map tiles, e.g. `saturate(0.2)`;
  /// empty string removes it.
  Future<void> setGroundFilter(String css) => _call('setGroundFilter', css);

  /// Calls `window.<fn>(<json>)`. JSON is a valid JS expression except for
  /// U+2028/U+2029, which are escaped.
  Future<void> _call(String fn, Object? arg) {
    final json = jsonEncode(
      arg,
    ).replaceAll(' ', r' ').replaceAll(' ', r' ');
    return _runJs('window.$fn($json)');
  }
}
