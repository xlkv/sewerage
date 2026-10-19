You are continuing the Flutter app "Turon" in the current directory. Step 1 (Supabase migrations, Edge Function, core, models, repositories, login, profile) is done. Read ../docs/LLD.md again; it is the source of truth. Keep Riverpod 3 / Freezed 3 as already used. Do NOT print or change env/dev.json.

Implement LLD "Amalga oshirish tartibi" steps 4, 5, 6, 7:
- Providers from LLD 4.4 (manholes/pipes/masters as realtime `.stream(primaryKey:['id'])`, status filter, map layer, map controller).
- Map screen (LLD 4.6): yandex_maps_mapkit_lite map; manholes as status-colored placemarks (code label at zoom >= 15), pipes as 2-point polylines in status color, mid-line arrow placemark rotated to from→to bearing; selection highlight; diff-update map objects by id; scheme/satellite toggle; initial camera = bbox of all objects, else current GPS (geolocator), else Tashkent; filter sheet by status; "Ulanish yo'q" chip when realtime/network is down.
- Map mode state machine exactly as LLD 4.5 (View, AddManhole, AddPipe(from), MoveManhole) as a pure Dart Notifier, with banners. Admin-only toolbar (+ Kolodets, + Quvur); user role sees no edit controls.
- Details cards and forms (LLD 4.7): manhole and pipe details (read-only for user), forms with validation, diameter chips + "Boshqa", manual length switch / "Avtoga qaytarish", swap direction, delete with confirm dialog and LLD 4.9 error messages. Client-side Haversine preview length in AddPipe before save.
- Adaptive UI (LLD 4.8): width >= 600 → map + 380dp side panel; phone → DraggableScrollableSheet for details, full-screen pages for forms.
- If SUPABASE_URL or SUPABASE_ANON_KEY is empty, show a friendly config-error screen instead of crashing (keys will be added later).
- Unit tests: every state-machine transition in LLD 4.5, status filter logic, Haversine, bearing, form validators.
- Run build_runner, `flutter analyze`, `flutter test`, and `flutter build apk --debug --dart-define-from-file=env/dev.json`; fix until all are clean. If the Yandex plugin API differs from LLD assumptions (drag, mapType, icon rotation), adapt and note it.

At the end print ONLY a short report (max 15 lines): areas done, analyze/test/build results, deviations from LLD with reason. No code.
