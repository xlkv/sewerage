import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/geo_utils.dart';
import '../../core/theme.dart';
import '../../data/repositories/pipe_repo.dart';
import '../../data/repositories/section_repo.dart';
import '../../shared/widgets/status_chip.dart';
import 'section_stats.dart';

/// All sections; pops with the tapped section id (shown on the map).
class SectionsScreen extends ConsumerWidget {
  final bool isAdmin;
  final VoidCallback? onCreate;

  const SectionsScreen({super.key, required this.isAdmin, this.onCreate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sectionsAsync = ref.watch(sectionsProvider);
    final pipesBySection =
        ref.watch(sectionPipesProvider).asData?.value ?? const {};
    final manholesBySection =
        ref.watch(sectionManholesProvider).asData?.value ?? const {};
    final allPipes = ref.watch(pipesProvider).asData?.value ?? const {};

    final sections = (sectionsAsync.asData?.value.values.toList() ?? [])
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Scaffold(
      appBar: AppBar(title: const Text('Uchastkalar')),
      floatingActionButton: isAdmin && onCreate != null
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).pop();
                onCreate!();
              },
              icon: const Icon(Icons.add_road_rounded),
              label: const Text('Yangi uchastka'),
            )
          : null,
      body: sectionsAsync.isLoading && sections.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : sections.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  isAdmin
                      ? 'Hali uchastka yo\'q. "Yangi uchastka" ni bosing va '
                            'xaritada boshi va oxiridagi kolodetsni tanlang.'
                      : 'Hali uchastka yo\'q',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
              itemCount: sections.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, i) {
                final s = sections[i];
                final stats = SectionStats.of(
                  pipeIds: pipesBySection[s.id] ?? const {},
                  manholeCount: manholesBySection[s.id]?.length ?? 0,
                  allPipes: allPipes,
                );
                return Card(
                  child: ListTile(
                    onTap: () => Navigator.of(context).pop(s.id),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.card),
                    ),
                    leading: Icon(
                      Icons.route_rounded,
                      color: AppColors.forStatus(s.status),
                    ),
                    title: Text(
                      s.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${formatLength(stats.lengthM)} · ${stats.pipeCount} quvur'
                      ' · ${stats.manholeCount} kolodets',
                    ),
                    trailing: StatusChip(status: s.status),
                  ),
                );
              },
            ),
    );
  }
}
