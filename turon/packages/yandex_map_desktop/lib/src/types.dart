import 'package:flutter/material.dart' show Color, immutable;

/// A geographic coordinate.
@immutable
class Point {
  final double latitude;
  final double longitude;

  const Point({required this.latitude, required this.longitude});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Point &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'Point(latitude: $latitude, longitude: $longitude)';

  Point copyWith({double? latitude, double? longitude}) => Point(
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
      );
}

/// Camera position on the map.
@immutable
class CameraPosition {
  final Point target;
  final double zoom;

  const CameraPosition({required this.target, this.zoom = 14.0});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CameraPosition &&
          runtimeType == other.runtimeType &&
          target == other.target &&
          zoom == other.zoom;

  @override
  int get hashCode => Object.hash(target, zoom);

  @override
  String toString() => 'CameraPosition(target: $target, zoom: $zoom)';

  CameraPosition copyWith({Point? target, double? zoom}) =>
      CameraPosition(target: target ?? this.target, zoom: zoom ?? this.zoom);
}

/// Describes how to update the camera.
///
/// Use the static factory methods to create instances.
abstract class CameraUpdate {
  const CameraUpdate._();

  /// Move the camera center to [point], optionally changing [zoom].
  static CameraUpdate newLatLng(Point point, {double? zoom}) =>
      LatLngCameraUpdate(point, zoom);

  /// Set a complete camera state.
  static CameraUpdate newCameraPosition(CameraPosition position) =>
      PositionCameraUpdate(position);

  /// Set the zoom level absolutely.
  static CameraUpdate zoomTo(double zoom) => ZoomCameraUpdate(zoom);

  /// Increase the current zoom by 1.
  static CameraUpdate zoomIn() => const ZoomDeltaCameraUpdate(1);

  /// Decrease the current zoom by 1.
  static CameraUpdate zoomOut() => const ZoomDeltaCameraUpdate(-1);
}

/// @nodoc Move to a lat/lng, optionally with a zoom.
class LatLngCameraUpdate extends CameraUpdate {
  final Point point;
  final double? zoom;
  const LatLngCameraUpdate(this.point, this.zoom) : super._();
}

/// @nodoc Full camera position update.
class PositionCameraUpdate extends CameraUpdate {
  final CameraPosition position;
  const PositionCameraUpdate(this.position) : super._();
}

/// @nodoc Absolute zoom update.
class ZoomCameraUpdate extends CameraUpdate {
  final double zoom;
  const ZoomCameraUpdate(this.zoom) : super._();
}

/// @nodoc Relative zoom delta update.
class ZoomDeltaCameraUpdate extends CameraUpdate {
  final double delta;
  const ZoomDeltaCameraUpdate(this.delta) : super._();
}

/// Icon descriptor for a placemark.
@immutable
class PlacemarkIcon {
  /// Fill color (used to render an SVG circle marker).
  final Color color;

  /// Diameter in logical pixels.
  final double size;

  const PlacemarkIcon({this.color = const Color(0xFF2196F3), this.size = 32});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlacemarkIcon &&
          runtimeType == other.runtimeType &&
          color == other.color &&
          size == other.size;

  @override
  int get hashCode => Object.hash(color, size);

  @override
  String toString() => 'PlacemarkIcon(color: $color, size: $size)';

  PlacemarkIcon copyWith({Color? color, double? size}) =>
      PlacemarkIcon(color: color ?? this.color, size: size ?? this.size);
}
