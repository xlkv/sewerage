# yandex_map_desktop

[![pub.dev](https://img.shields.io/pub/v/yandex_map_desktop.svg)](https://pub.dev/packages/yandex_map_desktop)
[![platform Windows](https://img.shields.io/badge/platform-Windows-blue.svg)](https://pub.dev/packages/yandex_map_desktop)
[![platform macOS](https://img.shields.io/badge/platform-macOS-blue.svg)](https://pub.dev/packages/yandex_map_desktop)
[![license MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

A Flutter widget that embeds the Yandex Maps JavaScript API 2.1 inside a native
WebView, bringing real Yandex tiles to Flutter desktop apps. Works on
**Windows** (Edge WebView2) and **macOS** (WKWebView). Designed to pair with
[`yandex_mapkit`](https://pub.dev/packages/yandex_mapkit) on mobile.

---

## Platform support

| Platform | Status                              |
|----------|-------------------------------------|
| Android  | ✅ Use [`yandex_mapkit`](https://pub.dev/packages/yandex_mapkit) |
| iOS      | ✅ Use [`yandex_mapkit`](https://pub.dev/packages/yandex_mapkit) |
| Windows  | ✅ This package                     |
| macOS    | ✅ This package                     |
| Web      | 🚧 Not yet                          |
| Linux    | 🚧 Not yet                          |

---

## Getting started

### 1. Add the dependency

```yaml
dependencies:
  yandex_map_desktop: ^0.1.0
```

### 2. Obtain a Yandex Maps API key

1. Sign in at [developer.tech.yandex.com](https://developer.tech.yandex.com).
2. Create a new project and enable **"JavaScript API and HTTP Geocoder"**.
3. Under *Restrictions*, set the domain to **"Without restrictions"** so the
   key works from the local WebView origin.

### 3. Windows: ensure WebView2 Runtime is present

Edge WebView2 Runtime is pre-installed on **Windows 11** and
**Windows 10 21H2+**. For older versions of Windows, users need to install it
separately — download it from the
[official Microsoft page](https://developer.microsoft.com/en-us/microsoft-edge/webview2/).

---

## Basic usage

```dart
YandexMapDesktop(
  apiKey: 'YOUR_JS_API_KEY',
  initialCameraPosition: CameraPosition(
    target: Point(latitude: 55.755864, longitude: 37.617698),
    zoom: 12,
  ),
  mapObjects: [
    PlacemarkMapObject(
      mapId: MapObjectId('my_marker'),
      point: Point(latitude: 55.755864, longitude: 37.617698),
      icon: PlacemarkIcon(color: Colors.red, size: 36),
      label: 'Moscow',
      onTap: (obj, point) => print('Tapped!'),
    ),
    PolylineMapObject(
      mapId: MapObjectId('route'),
      coordinates: [
        Point(latitude: 55.75, longitude: 37.61),
        Point(latitude: 55.76, longitude: 37.63),
      ],
      strokeColor: Colors.blue,
      strokeWidth: 4,
    ),
  ],
  onMapCreated: (controller) {
    // controller.moveCamera(CameraUpdate.zoomIn());
  },
  onMapTap: (point) => print('Map tapped at $point'),
  onMapLongTap: (point) => print('Long tap / right-click at $point'),
)
```

---

## Map objects

### `PlacemarkMapObject`

A pin / marker placed at a geographic coordinate.

| Property | Type            | Description                                    |
|----------|-----------------|------------------------------------------------|
| `mapId`  | `MapObjectId`   | Unique identifier used for reconciliation.     |
| `point`  | `Point`         | Geographic location.                           |
| `icon`   | `PlacemarkIcon` | Color and diameter of the SVG circle marker.   |
| `label`  | `String?`       | Optional text rendered below the marker.       |
| `opacity`| `double`        | 0.0 – 1.0 (default `1.0`).                    |
| `onTap`  | `Function?`     | Called when the marker is tapped.              |

### `PolylineMapObject`

An open path connecting two or more `Point`s.

| Property      | Type          | Description                                |
|---------------|---------------|--------------------------------------------|
| `mapId`       | `MapObjectId` | Unique identifier used for reconciliation. |
| `coordinates` | `List<Point>` | Ordered list of points forming the line.   |
| `strokeColor` | `Color`       | Line colour (default deep blue).           |
| `strokeWidth` | `double`      | Line width in logical pixels (default `3`).|
| `opacity`     | `double`      | 0.0 – 1.0 (default `1.0`).                |
| `onTap`       | `Function?`   | Called when the polyline is tapped.        |

---

## Controller

After `onMapCreated` fires you receive a `YandexMapDesktopController` that
lets you interact with the map programmatically.

```dart
// Zoom in by one level
controller.moveCamera(CameraUpdate.zoomIn());

// Zoom out by one level
controller.moveCamera(CameraUpdate.zoomOut());

// Set zoom absolutely
controller.moveCamera(CameraUpdate.zoomTo(15));

// Fly to a specific coordinate
controller.moveCamera(CameraUpdate.newLatLng(
  Point(latitude: 59.934280, longitude: 30.335099),
  zoom: 14,
));

// Set a full camera position at once
controller.moveCamera(CameraUpdate.newCameraPosition(
  CameraPosition(
    target: Point(latitude: 55.755864, longitude: 37.617698),
    zoom: 12,
  ),
));

// Read the last known camera position (no async call needed)
final pos = controller.getCameraPosition();
print('${pos.target.latitude}, ${pos.target.longitude} @ zoom ${pos.zoom}');
```

---

## How it works

The widget embeds the Yandex Maps JS API 2.1 in a WebView and communicates
with it via a **bidirectional JSON protocol**:

- **Dart → JS** – `_js(String code)` executes arbitrary JavaScript directly
  (`ctrl.executeScript` on Windows, `runJavaScript` on macOS).
- **JS → Dart** – events (`ready`, `mapTap`, `mapLongTap`, `cameraChange`,
  `objectTap`) are posted with `window.chrome.webview.postMessage` on Windows
  or dispatched through a named `JavaScriptChannel` called `FlutterChannel` on
  macOS.

The HTML page is generated at runtime by `_html_builder.dart` and loaded as a
string, so no file assets are needed.

---

## Contributing

Contributions, issues and feature requests are welcome!
Please open an issue or pull request on
[GitHub](https://github.com/xlkv/yandex_map_desktop).

When making changes to the JavaScript bridge, keep
`lib/src/_html_builder.dart` and `lib/src/widget.dart` in sync.

---

## License

MIT © 2024 yandex_map_desktop contributors. See [LICENSE](LICENSE) for details.
