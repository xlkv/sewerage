/// Yandex Maps JavaScript API 2.1 for Flutter Windows & macOS desktop via WebView.
library;

export 'src/types.dart';
export 'src/map_objects.dart';
export 'src/controller.dart';

// On web (dart.library.html available, dart.library.io absent) use the stub
// that compiles without dart:io or any native WebView import.
// On all other platforms (mobile, desktop) use the full implementation which
// selects Windows or macOS WebView at runtime via Platform checks.
export 'src/widget_stub.dart' if (dart.library.io) 'src/widget.dart';
