// ignore_for_file: avoid_unused_constructor_parameters

import 'package:flutter/material.dart';

import 'controller.dart';
import 'map_objects.dart';
import 'types.dart';

/// Stub implementation used on platforms where WebView is unavailable
/// (web, Linux, Android, iOS).
///
/// On those platforms [YandexMapDesktop] renders an informational message
/// instead of a live map.
class YandexMapDesktop extends StatelessWidget {
  final String apiKey;
  final CameraPosition initialCameraPosition;
  final List<MapObject> mapObjects;
  final void Function(YandexMapDesktopController controller)? onMapCreated;
  final void Function(Point point)? onMapTap;
  final void Function(Point point)? onMapLongTap;
  final void Function(CameraPosition position, bool finished)?
      onCameraPositionChanged;
  final void Function(String id, Point point)? onObjectTap;
  final void Function(String id, Point point)? onObjectDrag;
  final void Function(String id, Point point)? onObjectDragEnd;
  final VoidCallback? onUserAction;
  final String lang;
  final List<String> controls;

  const YandexMapDesktop({
    super.key,
    required this.apiKey,
    this.initialCameraPosition = const CameraPosition(
      target: Point(latitude: 55.755864, longitude: 37.617698),
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
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFEEEEEE),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'YandexMapDesktop is only supported on Windows and macOS.\n'
            'Use yandex_mapkit for Android/iOS or flutter_map for web.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF757575)),
          ),
        ),
      ),
    );
  }
}
