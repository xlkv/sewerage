You are continuing the Flutter app "Turon" in the current directory. Read ../docs/LLD.md for context. Do NOT print or change env/dev.json. Android emulator `emulator-5554` is running. All UI text Uzbek latin.

DB change already applied by Claude (migration supabase/migrations/20261019000006_manhole_free_sizes.sql): manholes.height_m and diameter_m are now numeric(10,2), only rule is `> 0` (or null). No upper limits.

## 1. Bug: adding a manhole fails with "Kiritilgan qiymat ruxsat etilgan oraliqda emas" (Postgres 23514)
Find the real cause in the manhole form/repository. Likely causes: empty optional number fields sent as 0 instead of null; comma decimal ("1,5") parsed wrongly; unit mismatch. Fix: empty → null, accept both "," and "." as decimal separator, max 2 decimals, only rule > 0. Remove all client-side upper limits for manhole height/diameter. Check the same for pipe form (empty manual length → null). Fix the code placeholder: it says "K-001" but DB generates "K-1"; show "Bo'sh qolsa avto (K-1, K-2…)".

## 2. Initial map location = Qarshi
Initial camera: if there are objects → fit bbox of all objects; otherwise Qarshi city center (lat 38.8606, lng 65.7898), zoom 13. Do NOT auto-jump to GPS on start; keep a "Mening joylashuvim" button for that. Replace every Tashkent default with Qarshi.

## 3. Manhole marker — more visible, code inside
Draw marker bitmap with Canvas: filled circle in status color, ~40dp diameter, 2.5dp white border, soft shadow, the manhole code (e.g. "K-12") centered in white bold text (auto-shrink font for long codes). Selected: 1.25x bigger + accent ring. At zoom < 14 draw a small 14dp dot without text. Cache bitmaps by (status, code, selected, zoomBucket). Pipes stay as is but make them 5dp so they are visible under markers.

## 4. iOS-style bottom sheet
Replace the details bottom sheet with a smooth, non-modal, iOS-like sheet (you may add the `smooth_sheets` package, or DraggableScrollableSheet with snap): grabber handle, 20dp top corners, spring animation, snap points ~28% / 55% / 92%, scroll inside content hands off to sheet drag, swipe down to dismiss, map stays interactive above it. Opening a different object animates content, not a new sheet. Forms (add/edit) open as a full-height sheet of the same style on phone; on tablet keep the 380dp side panel.

## 5. LLD step 8 — admin screens
- Foydalanuvchilar: list (name, formatted phone, role chip, active/blocked), search; add user (name, phone with the same masked input, role, 5-digit PIN using existing PinBoxes+NumericKeypad); edit name/role; block/unblock; reset PIN — all through Edge Function `admin-users` (LLD section 2), show its error codes in Uzbek (phone_exists → "Bu raqam allaqachon ro'yxatda", self_change → "O'zingizni o'zgartira olmaysiz").
- Ustalar: list with search, add/edit (name, optional phone with mask), activate/deactivate; inactive masters hidden from manhole dropdown but still shown on existing manholes.
- Admin-only routes guarded in router; user role cannot open them.

## 6. Pipes end-to-end
Make sure AddPipe mode works with the new markers (tap hit area = whole circle), Haversine preview, save, details sheet shows auto/manual length and direction arrow. Add tests.

## 7. Verify
build_runner, `flutter analyze`, `flutter test` (add tests for: empty optional fields → null, comma decimals, Qarshi default camera, marker cache key, admin form validation). Then `flutter build apk --debug --dart-define-from-file=env/dev.json` and `adb -s emulator-5554 install -r` it, launch it.

Print ONLY a short report (max 15 lines): root cause of bug 1, what changed per section, analyze/test/build results, deviations. No code.
