# Turon — Kanalizatsiya quvur va kolodets xaritasi

Dala va ofis xodimlari uchun Android Flutter ilovasi (Supabase + PostGIS + Yandex MapKit).

## Sozlash

1. `env/example.json` faylini `env/dev.json` ga nusxalang va kalitlarni to'ldiring:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `YANDEX_MAPKIT_KEY`

2. Ilovani ishga tushirish:

```bash
flutter run --dart-define-from-file=env/dev.json
```

## Windows

The Windows build uses the Yandex Maps **JavaScript API** in a WebView2
(`packages/yandex_map_desktop`, vendored and extended). It needs its own key:
developer.tech.yandex.ru → "JavaScript API and HTTP Geocoder", restriction
"Without restrictions". Put it into `env/dev.json` as `YANDEX_JS_KEY`.

```
flutter run -d windows --dart-define-from-file=env/dev.json
flutter build windows --release --dart-define-from-file=env/dev.json
```

WebView2 Runtime is preinstalled on Windows 10 21H2+ / 11.
