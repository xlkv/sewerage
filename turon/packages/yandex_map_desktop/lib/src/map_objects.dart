import 'package:flutter/material.dart' show Color, immutable;

import 'types.dart';

/// Unique identifier for a map object.
@immutable
class MapObjectId {
  final String value;
  const MapObjectId(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapObjectId &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'MapObjectId($value)';
}

/// Base class for all map objects.
abstract class MapObject {
  MapObjectId get mapId;
  double get opacity;
}

/// A pin / marker placed on the map.
class PlacemarkMapObject implements MapObject {
  @override
  final MapObjectId mapId;

  /// Geographic location of this placemark.
  final Point point;

  /// Visual icon descriptor.
  final PlacemarkIcon icon;

  /// Optional text label rendered below the marker.
  final String? label;

  @override
  final double opacity;

  /// Called when the placemark is tapped.
  ///
  /// [self] is this object; [tappedPoint] is the geographic coordinate of
  /// the tap (equal to [point] for placemarks).
  final void Function(PlacemarkMapObject self, Point tappedPoint)? onTap;

  const PlacemarkMapObject({
    required this.mapId,
    required this.point,
    this.icon = const PlacemarkIcon(),
    this.label,
    this.opacity = 1.0,
    this.onTap,
  });

  PlacemarkMapObject copyWith({
    MapObjectId? mapId,
    Point? point,
    PlacemarkIcon? icon,
    String? label,
    double? opacity,
    void Function(PlacemarkMapObject self, Point tappedPoint)? onTap,
  }) => PlacemarkMapObject(
    mapId: mapId ?? this.mapId,
    point: point ?? this.point,
    icon: icon ?? this.icon,
    label: label ?? this.label,
    opacity: opacity ?? this.opacity,
    onTap: onTap ?? this.onTap,
  );
}

/// A polyline (open path) connecting two or more [Point]s.
class PolylineMapObject implements MapObject {
  @override
  final MapObjectId mapId;

  /// Ordered list of geographic coordinates that form the line.
  final List<Point> coordinates;

  /// Stroke colour of the line.
  final Color strokeColor;

  /// Stroke width in logical pixels.
  final double strokeWidth;

  @override
  final double opacity;

  /// Called when the polyline is tapped.
  final void Function(PolylineMapObject self)? onTap;

  const PolylineMapObject({
    required this.mapId,
    required this.coordinates,
    this.strokeColor = const Color(0xFF1565C0),
    this.strokeWidth = 3.0,
    this.opacity = 1.0,
    this.onTap,
  });

  PolylineMapObject copyWith({
    MapObjectId? mapId,
    List<Point>? coordinates,
    Color? strokeColor,
    double? strokeWidth,
    double? opacity,
    void Function(PolylineMapObject self)? onTap,
  }) => PolylineMapObject(
    mapId: mapId ?? this.mapId,
    coordinates: coordinates ?? this.coordinates,
    strokeColor: strokeColor ?? this.strokeColor,
    strokeWidth: strokeWidth ?? this.strokeWidth,
    opacity: opacity ?? this.opacity,
    onTap: onTap ?? this.onTap,
  );
}
