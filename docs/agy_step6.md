You are continuing the Flutter app "Turon" in the current directory. Do NOT print or change env/dev.json. Emulator `emulator-5554` is running. UI text Uzbek latin.

Read ../docs/UX_REPORT_2.md and fix every item in "Qolgan muammolar" (#1–#5) as proposed.
- #1 is the most important and was NOT fixed last time. Reproduce it first: select a manhole, then (a) tap empty map, (b) press the sheet X, (c) swipe the sheet down — in all three the highlight ring must disappear. Root-cause it in the map objects diff (the selected/unselected bitmap must be part of the diff key) and in the selection state; add a regression test that fails before the fix.
- #2: when a manhole or pipe is selected, animate the camera so the object is centered in the visible map area above the sheet (account for the current sheet height; on tablet account for the side panel).
- #5: verify the satellite layer actually renders (zoom out/in on the emulator, check logcat); fix if needed.

Then: build_runner, `flutter analyze`, `flutter test` (all pass), `flutter build apk --debug --dart-define-from-file=env/dev.json`, `adb -s emulator-5554 install -r ...`, launch.

Print ONLY a short report (max 10 lines): root cause of #1, per item done/not done, analyze/test/build results. No code.
