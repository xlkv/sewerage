You are continuing the Flutter app "Turon" in the current directory. Do NOT print or change env/dev.json. Emulator `emulator-5554` is running. UI text Uzbek latin.

Task: full visual redesign following ../docs/DESIGN.md exactly ("Blueprint" design system). Read it fully first, also ../docs/LLD.md for behaviour. Behaviour and data flow must NOT change — only look, feel and animations (plus the new mini stats card).

Rules:
1. Create `lib/core/design/` with tokens (colors, radii, spacing, shadows, text styles) and a single ThemeData; remove ad-hoc colors from widgets. Bundle Manrope font (download the OFL variable TTF from the google/fonts GitHub repo into assets/fonts and register it).
2. Map: apply the desaturated map style via MapKit `setMapStyle` (log success/failure). Redraw manhole bitmaps as manhole covers per DESIGN 2 (planned dashed ring, in_progress pulse halo, completed ✓ notch; dot at zoom < 14). Pipes: casing + core, width by diameter, planned dashed, flow-dash animation for in_progress and selected pipes, selected glow.
3. Map animations per DESIGN 2 (drop-in marker, pipe draw-on, selection scale) driven by ONE ticker ≤ 30 fps, only for visible objects (max 40), paused in background / when nothing animates, disabled when `MediaQuery.disableAnimations`.
4. KEEP the existing native redraw workaround in map_screen.dart (`_requestNativeMapRedraw`, signature + two timers) — it fixes a real bug (MapView does not present frames without camera movement). Your animation ticker must NOT call it every frame; check on the emulator that animations actually render (if frames are not presented while animating, find a proper fix, e.g. render-mode/texture settings, and document it).
5. Screens per DESIGN 3: floating top panel, mini stats card (client-side from providers: meters per status, counts; expandable; count-up animation), speed-dial FAB, mode banner pill, redesigned details sheet, forms, login animations, fade-through transitions, empty states, floating snackbars. Phone and tablet layouts both.
6. Performance: no jank — keep the map widget out of rebuilds caused by sheet/stats changes (use `select`/separate consumers), cache bitmaps, const widgets.
7. Update/add tests (tokens, stats aggregation, pipe width mapping, ticker pause logic). build_runner, `flutter analyze`, `flutter test` must be clean. Then `flutter build apk --debug --dart-define-from-file=env/dev.json`, `adb -s emulator-5554 install -r ...`, launch.

Print ONLY a short report (max 15 lines): what was redesigned, how animations are driven, map style result (log line), analyze/test/build results, deviations. No code.
