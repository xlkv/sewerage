## 0.2.1

- Windows: wheel / trackpad-pinch zoom now really anchors at the cursor.
  `webview_windows` forwards wheel events to the page with the position
  (0, 0), which zoomed towards the top-left corner; the widget now handles
  them in Flutter and calls `window.zoomAt` with the real position.

## 0.2.0

- Wheel zoom now keeps the point under the cursor fixed: computed from the
  target state of the previous wheel step through the map projection, and
  small trackpad deltas are accumulated.
- Imperative object API: `defineIcons`, `upsert`, `remove` (only changed
  objects are sent; no more remove-all/re-add on every update).
- Image placemarks (data-URI icons, anchor, rotation, scale, opacity,
  z-index, centred text, CSS class e.g. `ymd-pulse`), draggable with
  `onObjectDrag` / `onObjectDragEnd`.
- Text pills and multi-stroke / dashed polylines.
- `moveCamera(..., duration:)`, `setMapType`, `setGroundFilter`.
- `onObjectTap`, `onUserAction`, `lang`, `controls` (no built-in controls
  by default).

## 0.1.4

* **Fix:** Shortened `pubspec.yaml` description to satisfy the 60–180 character
  requirement (was being truncated by search engines).
* **Fix:** Replaced deprecated `Color.value` with `.red`/`.green`/`.blue`
  component accessors in `_colorToHex`.
* **Improvement:** Added `platforms: windows:, macos:` to `pubspec.yaml` so
  pub.dev platform detection is explicit.
* **Improvement:** Added a web/unsupported-platform stub (`widget_stub.dart`)
  and switched the library export to a conditional
  `if (dart.library.io) 'src/widget.dart'` so the package compiles on all
  six Dart platforms without errors.

## 0.1.3

* **Fix:** Scroll-wheel zoom now reliably zooms toward the cursor. Previous
  fix still had two bugs: (1) `wheel` listener lacked `capture: true` so
  Yandex Maps' own listener could still win the event race; (2)
  `getGlobalPixelCenter()` returned stale values in WebView2. Replaced with
  `capture:true` + `stopImmediatePropagation()` + `getBounds()`-based math:
  cursor fraction × visible bounds gives the geo point under the cursor;
  `newCenter = cursorGeo + (center - cursorGeo) / 2^ΔZoom` keeps it
  stationary on screen.

## 0.1.2

* **Fix:** Scroll-wheel zoom now zooms toward the cursor position on Windows
  (WebView2) and macOS (WKWebView). The built-in `scrollZoom` behaviour was
  replaced with a custom `wheel` event handler that uses
  `map.getGlobalPixelCenter()` + `projection.fromGlobalPixels /
  toGlobalPixels` to keep the geo-point under the cursor stationary during
  zoom.

## 0.1.1

* **Breaking:** Renamed `YandexMapWindows` → `YandexMapDesktop` and
  `YandexMapWindowsController` → `YandexMapDesktopController`.

## 0.1.0

* Initial release.
* `YandexMapDesktop` widget for Windows and macOS.
* `PlacemarkMapObject` with color, size and label support.
* `PolylineMapObject` with stroke color and width.
* `YandexMapDesktopController` with `moveCamera` and `getCameraPosition`.
* `onMapTap`, `onMapLongTap`, `onCameraPositionChanged` callbacks.
* Right-click to fire `onMapLongTap` on desktop.
* Graceful error widget when WebView2 runtime is missing.
