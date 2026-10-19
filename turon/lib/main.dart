import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yandex_maps_mapkit_lite/init.dart' as mapkit_init;

import 'app.dart';
import 'core/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('uz');

  if (Env.isSupabaseConfigured) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: Env.supabaseAnonKey,
    );
  }

  if (Env.isMapkitConfigured) {
    try {
      await mapkit_init.initMapkit(
        apiKey: Env.yandexMapkitApiKey,
        locale: 'uz_UZ',
      );
      debugPrint(
        'TuronMapKit: initMapkit succeeded (locale=uz_UZ, keyConfigured=true, len=${Env.yandexMapkitApiKey.length})',
      );
    } catch (e) {
      debugPrint('TuronMapKit: uz_UZ locale failed ($e), falling back to ru_RU');
      try {
        await mapkit_init.initMapkit(
          apiKey: Env.yandexMapkitApiKey,
          locale: 'ru_RU',
        );
        debugPrint(
          'TuronMapKit: initMapkit fallback succeeded (locale=ru_RU)',
        );
      } catch (e2) {
        // Ignore MapKit init errors on unsupported host platforms or missing native libs.
        debugPrint('TuronMapKit: initMapkit error: $e2');
      }
    }
  }

  runApp(const ProviderScope(child: TuronApp()));
}
