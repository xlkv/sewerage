class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const yandexMapkitApiKey = String.fromEnvironment(
    'YANDEX_MAPKIT_KEY',
  );

  static bool get isSupabaseConfigured =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  static bool get isMapkitConfigured => yandexMapkitApiKey.trim().isNotEmpty;
}
