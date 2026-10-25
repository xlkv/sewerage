import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const yandexMapkitApiKey = String.fromEnvironment(
    'YANDEX_MAPKIT_KEY',
  );

  static bool get isSupabaseConfigured =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  /// Yandex Maps JavaScript API key ("JavaScript API and HTTP Geocoder"),
  /// used by the Windows/macOS map.
  static const yandexJsApiKey = String.fromEnvironment('YANDEX_JS_KEY');

  /// Windows and macOS use the WebView (JS API) map, Android/iOS MapKit.
  static bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS);

  static bool get isMapkitConfigured =>
      !isDesktop && yandexMapkitApiKey.trim().isNotEmpty;

  static bool get isDesktopMapConfigured =>
      isDesktop && yandexJsApiKey.trim().isNotEmpty;
}
