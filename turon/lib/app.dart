import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/env.dart';
import 'core/router.dart';
import 'core/theme.dart';

final isSupabaseConfiguredProvider = Provider<bool>((ref) {
  return Env.isSupabaseConfigured;
});

class TuronApp extends ConsumerWidget {
  const TuronApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConfigured = ref.watch(isSupabaseConfiguredProvider);
    if (!isConfigured) {
      return MaterialApp(
        title: 'Turon',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const ConfigErrorScreen(),
      );
    }

    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Turon',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}

class ConfigErrorScreen extends StatelessWidget {
  const ConfigErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Turon — Sozlash xatosi')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.settings_suggest_outlined,
                      size: 56,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Ilova konfiguratsiyasi topilmadi',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'SUPABASE_URL yoki SUPABASE_ANON_KEY ko\'rsatilmagan.\n'
                      'Ilovani ishga tushirishda --dart-define-from-file=env/dev.json '
                      'parametrini qo\'shing.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
