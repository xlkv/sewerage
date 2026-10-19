import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/models/work_status.dart';
import 'map_controller.dart';

class FilterSheet extends ConsumerWidget {
  const FilterSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(statusFilterProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Status bo\'yicha filtr',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(statusFilterProvider.notifier).selectAll();
                  },
                  child: const Text('Barchasi'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final status in WorkStatus.values)
              CheckboxListTile(
                value: selected.contains(status),
                secondary: CircleAvatar(
                  radius: 8,
                  backgroundColor: AppColors.forStatus(status),
                ),
                title: Text(status.label),
                onChanged: (_) {
                  ref.read(statusFilterProvider.notifier).toggle(status);
                },
              ),
          ],
        ),
      ),
    );
  }
}
