You are continuing the Flutter app "Turon" in the current directory. Read ../docs/LLD.md for context. Do NOT print or change env/dev.json. An Android emulator is running as `emulator-5554`.

Already fixed by Claude: lib/core/env.dart now reads `YANDEX_MAPKIT_KEY` (it read the wrong name before, so the map showed the empty fallback canvas).

## Task A — Login UX redesign (Uzbek users only)
Two-step login, Telegram-like, clean and big touch targets. Never open the system keyboard on these screens.
1. **Phone step**: fixed non-editable prefix `+998`; user types only 9 digits; live mask `+998 (90) 123-45-67`. Validate operator code (first 2 digits) is a real Uzbek code (33, 50, 55, 77, 88, 90, 91, 93, 94, 95, 97, 98, 99, 20); show inline error otherwise. "Davom etish" button enabled only when 9 valid digits.
2. **PIN step**: shows the formatted phone + "O'zgartirish" link back to step 1. 5 separate PIN boxes (like Telegram code input): active box highlighted, filled boxes show a dot, on 5th digit auto-submit login; on wrong PIN shake the boxes, clear them, show "Telefon yoki parol noto'g'ri"; show progress indicator while signing in.
3. **Custom numeric keypad widget** (shared/widgets/numeric_keypad.dart): 3x4 grid 1-9, empty, 0, backspace (long-press clears all); haptic feedback; ripple; works for both steps. Reuse the same PIN boxes + keypad in profile "PIN o'zgartirish" (old PIN → new PIN → repeat new PIN).
4. Tablet (width >= 600): center the login card max-width 420.
5. Widget tests: mask formatting, operator validation, keypad input/backspace/long-press clear, auto-submit on 5th digit.

## Task B — Verify the map really works on the emulator
1. Run `flutter run -d emulator-5554 --dart-define-from-file=env/dev.json` (or build+install the debug APK and launch it).
2. Log in is not possible for you (no PIN) — so for verification temporarily confirm via logcat (`adb logcat --pid=$(adb shell pidof uz.turon.app)`) that MapKit initializes with a non-empty key and there are no MapKit errors; and confirm in code that MapScreen uses the real YandexMap widget (not the fallback canvas) when the key is set. If MapKit logs show an auth/key or rendering error, fix it (e.g. API key init order, mapkit.onStart lifecycle, Android manifest, emulator GPU fallback).
3. Remove nothing from LLD behaviour.

Finally run build_runner, `flutter analyze`, `flutter test`; fix until clean. Print ONLY a short report (max 15 lines): what changed, analyze/test results, map verification findings (quote the key log lines), deviations. No code.
