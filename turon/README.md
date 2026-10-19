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
