You are continuing the Flutter app "Turon" in the current directory. Do NOT print or change env/dev.json. Emulator `emulator-5554` is running. UI text Uzbek latin.

Read ../docs/UX_REPORT_1.md and fix every item in the "Muammolar" table (#1–#12) exactly as proposed there. Notes:
- #1: after a successful insert/update/delete in repositories, update the local provider state immediately with the returned row; realtime events must be idempotent (same id → replace, no duplicates).
- #2: LLD 4.8 says admin menu lives in a NavigationDrawer — follow it; user role sees only Xarita and Profil.
- #3: one shared `formatLength(double meters)` helper used everywhere (cards, forms, lists).
- #10: set MapKit locale before init; if `uz_UZ` is rejected fall back to `ru_RU`.
Also make sure the manhole code label is visible inside the marker at zoom >= 14 (verify by zooming the camera programmatically in a widget/integration test or by logging the chosen bitmap variant).

## Additional user feedback (must fix)
A. **Phone input everywhere** (Usta add/edit, Foydalanuvchi add/edit): reuse the login phone input — fixed `+998` prefix, live mask `+998 (90) 123-45-67`, our custom NumericKeypad (no system keyboard; keypad slides up inside the sheet when the phone field is focused, hides on other fields). Optional for masters (empty allowed). Backspace must delete digits correctly through mask characters.
B. **Delete does not work** (user report, mainly in Ustalar): investigate every delete action — masters, manholes, pipes. Masters: add "O'chirish" with confirm dialog; hard delete works because `manholes.master_id` is ON DELETE SET NULL; refresh the list immediately. Manholes with pipes must show the LLD 4.9 message; pipes delete must remove the line from the map immediately. Check the result of each delete call (RLS can silently delete 0 rows → show an error if 0 rows affected). Add tests.
C. **Manhole select/unselect is buggy** — required behaviour: tap marker → select it (highlight ring) and open its sheet; tap another marker → switch selection + sheet content; tap empty map or close/swipe down the sheet → clear selection AND remove highlight; tapping the selected marker again keeps it selected; selection highlight must never stay on a marker after the sheet is closed; in AddPipe/MoveManhole modes taps follow LLD 4.5 and do not open the sheet. Same rules for pipes. Add state-machine tests for these.

Finally: build_runner, `flutter analyze`, `flutter test` (all must pass, add tests for formatLength and optimistic state merge), then `flutter build apk --debug --dart-define-from-file=env/dev.json`, `adb -s emulator-5554 install -r ...`, launch.

Print ONLY a short report (max 12 lines): per item done/not done, analyze/test/build results. No code.
