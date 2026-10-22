// Private helper – do not import this file directly from outside the package.

/// Builds a complete HTML document that hosts Yandex Maps JavaScript API 2.1.
///
/// Parameters:
/// * [apiKey]  – Yandex Maps JS API key (get one at https://developer.tech.yandex.com).
/// * [lat] / [lng] / [zoom] – initial camera position (defaults to Moscow).
/// * [lang] – map language, e.g. `ru_RU`, `uz_UZ`, `en_US`.
/// * [controls] – built-in Yandex controls to show (none by default).
String buildMapHtml(
  String apiKey, {
  double lat = 55.755864,
  double lng = 37.617698,
  double zoom = 14.0,
  String lang = 'ru_RU',
  List<String> controls = const [],
}) {
  final controlsJs = '[${controls.map((c) => "'$c'").join(',')}]';
  return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body, #map { width: 100%; height: 100%; overflow: hidden; }
    .ymd-ph { position: absolute; }
    .ymd-ph img { display: block; pointer-events: none; user-select: none; }
    .ymd-ph .ymd-txt {
      position: absolute; left: 0; top: 0; width: 100%; height: 100%;
      display: flex; align-items: center; justify-content: center;
      color: #fff; font: 800 11px/1 "Segoe UI", system-ui, sans-serif;
      letter-spacing: -0.2px; white-space: nowrap; pointer-events: none;
    }
    .ymd-pill {
      position: absolute; transform: translate(-50%, 4px);
      padding: 3px 8px; border-radius: 999px; background: #fff;
      border: 1px solid #E2E8F0; color: #0F172A; white-space: nowrap;
      font: 700 11px/1.2 "Segoe UI", system-ui, sans-serif;
    }
    @keyframes ymd-pulse {
      from { transform: scale(1);   opacity: 0.55; }
      to   { transform: scale(1.9); opacity: 0; }
    }
    .ymd-pulse { animation: ymd-pulse 1.6s ease-out infinite; }
  </style>
</head>
<body>
  <div id="map"></div>
  <script src="https://api-maps.yandex.ru/2.1/?apikey=$apiKey&lang=$lang" type="text/javascript"></script>
  <script type="text/javascript">

    // -------------------------------------------------------------------------
    // Cross-platform message bridge to Flutter
    // -------------------------------------------------------------------------
    function _emit(obj) {
      var msg = JSON.stringify(obj);
      if (window.chrome && window.chrome.webview) {
        window.chrome.webview.postMessage(msg);      // Windows – WebView2
      } else if (window.FlutterChannel) {
        window.FlutterChannel.postMessage(msg);      // macOS – WKWebView
      }
    }

    var _map = null;
    var _geo = {};      // id -> ymaps GeoObject
    var _kind = {};     // id -> 'image' | 'pill' | 'polyline' | legacy kinds
    var _icons = {};    // icon key -> data URI
    var _ImgLayout = null;
    var _PillLayout = null;
    var _progMove = false;

    ymaps.ready(function () {
      _map = new ymaps.Map(
        'map',
        { center: [$lat, $lng], zoom: $zoom, controls: $controlsJs },
        { suppressMapOpenBlock: true, yandexMapDisablePoiInteractivity: true }
      );

      _ImgLayout = ymaps.templateLayoutFactory.createClass(
        '<div class="ymd-ph {{ properties.cls }}" style="' +
          'left:{{ properties.l }}px;top:{{ properties.t }}px;' +
          'width:{{ properties.w }}px;height:{{ properties.h }}px;' +
          'opacity:{{ properties.op }};' +
          'transform:rotate({{ properties.rot }}deg) scale({{ properties.sc }});' +
          'transform-origin:{{ properties.ox }}px {{ properties.oy }}px;">' +
          '<img src="{{ properties.href|raw }}" width="{{ properties.w }}" height="{{ properties.h }}"/>' +
          '<div class="ymd-txt" style="font-size:{{ properties.fs }}px">{{ properties.txt }}</div>' +
        '</div>'
      );
      _PillLayout = ymaps.templateLayoutFactory.createClass(
        '<div class="ymd-pill">{{ properties.txt }}</div>'
      );

      // ---------------------------------------------------------------------
      // Wheel zoom towards the cursor.
      // The built-in scrollZoom loses the cursor origin in WebView2, so we
      // zoom ourselves. Everything is computed from the TARGET state of the
      // previous wheel step (not the half-animated map), through the map
      // projection (exact Mercator), and small trackpad deltas are summed.
      // ---------------------------------------------------------------------
      _map.behaviors.disable('scrollZoom');
      var _md = document.getElementById('map');
      var _wheelAcc = 0, _tgtZoom = null, _tgtCenter = null, _tgtTimer = null;
      _md.addEventListener('wheel', function (e) {
        e.preventDefault();
        e.stopImmediatePropagation();
        var dy = e.deltaMode === 1 ? e.deltaY * 33 : e.deltaY;
        _wheelAcc += dy;
        if (Math.abs(_wheelAcc) < 50) return;
        var step = _wheelAcc < 0 ? 1 : -1;
        _wheelAcc = 0;

        var zoom0   = _tgtZoom !== null ? _tgtZoom : _map.getZoom();
        var center0 = _tgtCenter || _map.getCenter();
        var newZoom = Math.max(2, Math.min(21, Math.round(zoom0) + step));
        if (newZoom === zoom0) return;

        var proj = _map.options.get('projection');
        var rect = _md.getBoundingClientRect();
        var ox = e.clientX - rect.left - rect.width / 2;
        var oy = e.clientY - rect.top  - rect.height / 2;
        var c0 = proj.toGlobalPixels(center0, zoom0);
        var cursorGeo = proj.fromGlobalPixels([c0[0] + ox, c0[1] + oy], zoom0);
        var c1 = proj.toGlobalPixels(cursorGeo, newZoom);
        var newCenter = proj.fromGlobalPixels([c1[0] - ox, c1[1] - oy], newZoom);

        _tgtZoom = newZoom;
        _tgtCenter = newCenter;
        clearTimeout(_tgtTimer);
        _tgtTimer = setTimeout(function () { _tgtZoom = null; _tgtCenter = null; }, 300);
        _emit({ type: 'userAction' });
        _map.setCenter(newCenter, newZoom, { duration: 180, checkZoomRange: true });
      }, { passive: false, capture: true });

      _map.events.add('click', function (e) {
        var c = e.get('coords');
        _emit({ type: 'mapTap', lat: c[0], lng: c[1] });
      });
      _map.events.add('contextmenu', function (e) {
        var c = e.get('coords');
        _emit({ type: 'mapLongTap', lat: c[0], lng: c[1] });
      });

      // Camera changes, at most once per animation frame.
      var _camQueued = false;
      _map.events.add('boundschange', function () {
        if (_camQueued) return;
        _camQueued = true;
        requestAnimationFrame(function () {
          _camQueued = false;
          var c = _map.getCenter();
          _emit({ type: 'cameraChange', lat: c[0], lng: c[1], zoom: _map.getZoom(), finished: false });
        });
      });
      _map.events.add('actionend', function () {
        _progMove = false;
        var c = _map.getCenter();
        _emit({ type: 'cameraChange', lat: c[0], lng: c[1], zoom: _map.getZoom(), finished: true });
      });
      // A drag by the user (programmatic moves set _progMove first).
      _map.events.add('actionbegin', function () {
        if (!_progMove) _emit({ type: 'userAction' });
      });

      _emit({ type: 'ready' });
    });

    // -------------------------------------------------------------------------
    // Objects
    // -------------------------------------------------------------------------
    function _svgCircle(color, size) {
      var r = size / 2, ir = r - 2.5;
      var svg = '<svg xmlns="http://www.w3.org/2000/svg" width="' + size + '" height="' + size + '">' +
        '<circle cx="' + r + '" cy="' + r + '" r="' + ir + '" fill="' + color + '" stroke="white" stroke-width="2.5"/></svg>';
      return 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg);
    }

    function _imgProps(it) {
      var w = it.w, h = it.h;
      var ax = (it.ax === undefined ? 0.5 : it.ax), ay = (it.ay === undefined ? 0.5 : it.ay);
      return {
        href: it.href || _icons[it.icon] || '',
        w: w, h: h, l: -ax * w, t: -ay * h, ox: ax * w, oy: ay * h,
        rot: it.rot || 0, sc: (it.sc === undefined ? 1 : it.sc),
        op: (it.op === undefined ? 1 : it.op),
        txt: it.txt || '', fs: it.fs || 11, cls: it.cls || '',
        hintContent: it.hint || ''
      };
    }

    function _shape(p) {
      return { type: 'Rectangle', coordinates: [[p.l, p.t], [p.l + p.w, p.t + p.h]] };
    }

    function _strokeOpts(it) {
      var s = it.strokes || [{ c: it.strokeColor || '#1E3A8A', w: it.strokeWidth || 3, s: 'solid' }];
      return {
        strokeColor: s.map(function (x) { return x.c; }),
        strokeWidth: s.map(function (x) { return x.w; }),
        strokeStyle: s.map(function (x) { return x.s || 'solid'; }),
        opacity: (it.op === undefined ? (it.opacity === undefined ? 1 : it.opacity) : it.op),
        zIndex: it.z || 0
      };
    }

    function _points(it) {
      return it.points.map(function (p) { return Array.isArray(p) ? p : [p.lat, p.lng]; });
    }

    function _create(it) {
      var geo;
      if (it.type === 'image' || it.type === 'placemark') {
        if (it.type === 'placemark') {           // legacy circle marker
          it = { id: it.id, lat: it.lat, lng: it.lng, href: _svgCircle(it.color, it.size),
                 w: it.size, h: it.size, op: it.opacity, hint: it.label };
        }
        var p = _imgProps(it);
        geo = new ymaps.Placemark([it.lat, it.lng], p, {
          iconLayout: _ImgLayout, iconShape: _shape(p),
          zIndex: it.z || 0, draggable: !!it.drag, hasHint: !!it.hint, openBalloonOnClick: false
        });
      } else if (it.type === 'pill') {
        geo = new ymaps.Placemark([it.lat, it.lng], { txt: it.txt || '' }, {
          iconLayout: _PillLayout,
          iconShape: { type: 'Rectangle', coordinates: [[-40, 2], [40, 22]] },
          zIndex: it.z || 0, openBalloonOnClick: false
        });
      } else if (it.type === 'polyline') {
        geo = new ymaps.Polyline(_points(it), { hintContent: it.hint || '' }, _strokeOpts(it));
      }
      if (!geo) return null;
      var id = it.id;
      geo.events.add('click', function (e) {
        e.stopPropagation();
        var c = e.get('coords') || [0, 0];
        _emit({ type: 'objectTap', id: id, lat: c[0], lng: c[1] });
      });
      if (it.type === 'image') {
        var dragQueued = false;
        geo.events.add('drag', function () {
          if (dragQueued) return;
          dragQueued = true;
          requestAnimationFrame(function () {
            dragQueued = false;
            var c = geo.geometry.getCoordinates();
            _emit({ type: 'objectDrag', id: id, lat: c[0], lng: c[1] });
          });
        });
        geo.events.add('dragend', function () {
          var c = geo.geometry.getCoordinates();
          _emit({ type: 'objectDragEnd', id: id, lat: c[0], lng: c[1] });
        });
      }
      return geo;
    }

    function _update(geo, it) {
      if (it.type === 'image') {
        var p = _imgProps(it);
        geo.geometry.setCoordinates([it.lat, it.lng]);
        geo.properties.set(p);
        geo.options.set({ iconShape: _shape(p), zIndex: it.z || 0, draggable: !!it.drag, hasHint: !!it.hint });
      } else if (it.type === 'pill') {
        geo.geometry.setCoordinates([it.lat, it.lng]);
        geo.properties.set({ txt: it.txt || '' });
        geo.options.set({ zIndex: it.z || 0 });
      } else if (it.type === 'polyline') {
        geo.geometry.setCoordinates(_points(it));
        geo.options.set(_strokeOpts(it));
      }
    }

    /// Registers reusable icons: {key: dataUri}.
    window.defineIcons = function (map) {
      for (var k in map) if (map.hasOwnProperty(k)) _icons[k] = map[k];
    };

    /// Adds or updates objects (matched by id).
    window.upsert = function (items) {
      if (!_map) return;
      items.forEach(function (it) {
        var geo = _geo[it.id];
        if (geo && _kind[it.id] === it.type) {
          _update(geo, it);
          return;
        }
        if (geo) _map.geoObjects.remove(geo);
        geo = _create(it);
        if (geo) {
          _map.geoObjects.add(geo);
          _geo[it.id] = geo;
          _kind[it.id] = it.type;
        } else {
          delete _geo[it.id];
          delete _kind[it.id];
        }
      });
    };

    window.remove = function (ids) {
      if (!_map) return;
      ids.forEach(function (id) {
        var geo = _geo[id];
        if (geo) _map.geoObjects.remove(geo);
        delete _geo[id];
        delete _kind[id];
      });
    };

    /// Replaces ALL objects (declarative API of 0.1.x).
    window.setObjects = function (items) {
      window.remove(Object.keys(_geo));
      window.upsert(items);
    };

    // -------------------------------------------------------------------------
    // Camera & map look
    // -------------------------------------------------------------------------
    /// {lat, lng, zoom?, duration? (ms), animated? (legacy: 300 ms)}
    window.moveCamera = function (args) {
      if (!_map) return;
      var zoom = (args.zoom !== undefined) ? args.zoom : _map.getZoom();
      var duration = args.duration !== undefined ? args.duration : (args.animated ? 300 : 0);
      _progMove = true;
      _map.setCenter([args.lat, args.lng], Math.round(zoom),
        duration > 0 ? { duration: duration, timingFunction: 'ease-in-out', checkZoomRange: true }
                     : { checkZoomRange: true });
    };

    /// 'yandex#map' | 'yandex#satellite' | 'yandex#hybrid'
    window.setMapType = function (type) { if (_map) _map.setType(type); };

    /// CSS filter for the base map tiles (e.g. 'saturate(0.2)'), '' = none.
    window.setGroundFilter = function (css) {
      if (!_map) return;
      var pane = _map.panes.get('ground');
      if (pane && pane.getElement) pane.getElement().style.filter = css || '';
    };

  </script>
</body>
</html>''';
}
