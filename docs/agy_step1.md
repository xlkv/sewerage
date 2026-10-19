You are implementing the Android Flutter app "Turon". Read ../docs/HLD.md and ../docs/LLD.md fully first; LLD is the source of truth. Work inside the current directory (it already contains env/dev.json — do NOT print or change its keys).

Do LLD "Amalga oshirish tartibi" step 1 (code only, no cloud) + step 3:
1. Supabase: `supabase init` here, then create supabase/migrations/ with the 4 migrations from LLD 1.1–1.4 exactly (timestamped names). Add supabase/seed_first_admin.sql template from LLD 1.5.
2. Edge Function supabase/functions/admin-users/index.ts per LLD section 2 (Deno, supabase-js v2, uses SUPABASE_SERVICE_ROLE_KEY env, shared derivePassword/pseudoEmail exactly as LLD section 3).
3. Flutter: `flutter create --org uz.turon --project-name turon --platforms android .` (Android only, package uz.turon.app). Add packages from LLD 4.1 (latest stable versions that resolve; for yandex_maps_mapkit_lite follow its pub.dev Android setup, minSdk etc.). Create the folder structure from LLD 4.2. Implement now: main.dart (env via String.fromEnvironment, Supabase.initialize, MapKit init with YANDEX_MAPKIT_KEY), app.dart, core/* (env, router with auth redirect, theme with status colors, auth_utils, errors mapping LLD 4.9, responsive), data/models (freezed + json_serializable, snake_case json), data/repositories (all 5), features/auth/login_screen (phone + 5-digit PIN), features/profile/profile_screen (change PIN, logout), and a placeholder map_screen (Scaffold with drawer per LLD 4.8). UI text in Uzbek latin.
4. .gitignore entries for env/*.json except env/example.json (create it with empty values) and README.md with run command: flutter run --dart-define-from-file=env/dev.json
5. Unit tests: normalizePhone, pseudoEmail, derivePassword, error mapping.
6. Run build_runner, `flutter analyze` and `flutter test`; fix until both are clean.

At the end print ONLY a short report (max 15 lines): areas created, analyze result, test result, any deviation from LLD with reason. No code in the report.
