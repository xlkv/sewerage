import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth_utils.dart';
import '../../../core/errors.dart';
import '../../../data/models/master.dart';
import '../../../data/repositories/manhole_repo.dart';
import '../../../data/repositories/master_repo.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import 'master_form.dart';

class MastersScreen extends ConsumerStatefulWidget {
  const MastersScreen({super.key});

  @override
  ConsumerState<MastersScreen> createState() => _MastersScreenState();
}

class _MastersScreenState extends ConsumerState<MastersScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Master> _filterMasters(List<Master> masters) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return masters;
    final qDigits = q.replaceAll(RegExp(r'\D'), '');
    return masters.where((m) {
      final matchesName = m.fullName.toLowerCase().contains(q);
      final phone = m.phone;
      if (phone == null || phone.isEmpty) {
        return matchesName;
      }
      final matchesPhone =
          phone.toLowerCase().contains(q) ||
          formatUzbekPhoneMask(phone).toLowerCase().contains(q) ||
          (qDigits.isNotEmpty && phone.contains(qDigits));
      return matchesName || matchesPhone;
    }).toList();
  }

  Future<void> _openCreateSheet() async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const MasterForm(),
    );
  }

  Future<void> _openEditSheet(Master master) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => MasterForm(initialMaster: master),
    );
  }

  Future<void> _toggleActive(Master master) async {
    final nextActive = !master.isActive;
    try {
      await ref.read(masterRepoProvider).update(
            master.id,
            isActive: nextActive,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nextActive
                  ? '${master.fullName} faollashtirildi'
                  : '${master.fullName} nofaol qilindi',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mapErrorToMessage(e))),
        );
      }
    }
  }

  Future<void> _deleteMaster(Master master) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Ustani o\'chirish',
      message: '${master.fullName} ustani haqiqatan ham o\'chirmoqchimisiz?',
      confirmLabel: 'O\'chirish',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    try {
      await ref.read(masterRepoProvider).delete(master.id);
      ref.read(manholeRepoProvider).clearMasterLocally(master.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${master.fullName} o\'chirildi')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mapErrorToMessage(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mastersAsync = ref.watch(mastersProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ustalar'),
        actions: [
          IconButton(
            tooltip: 'Yangilash',
            onPressed: () => ref.invalidate(mastersProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: (mastersAsync.asData?.value.isNotEmpty ?? false)
          ? FloatingActionButton.extended(
              key: const ValueKey('masters_add_fab'),
              onPressed: _openCreateSheet,
              icon: const Icon(Icons.add),
              label: const Text('Usta qo\'shish'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              key: const ValueKey('masters_search_field'),
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Ism yoki telefon orqali qidirish…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                        icon: const Icon(Icons.clear),
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: mastersAsync.when(
              data: (masters) {
                if (masters.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.engineering_outlined,
                            size: 48,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Hali usta qo\'shilmagan',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            key: const ValueKey('masters_empty_add_btn'),
                            onPressed: _openCreateSheet,
                            icon: const Icon(Icons.add),
                            label: const Text('Usta qo\'shish'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final filtered = _filterMasters(masters);
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('Ustalar topilmadi'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final master = filtered[index];
                    final statusLabel = master.isActive ? 'Faol' : 'Nofaol';
                    final statusColor = master.isActive
                        ? const Color(0xFF16A34A)
                        : colorScheme.onSurfaceVariant;
                    final phoneDisplay =
                        (master.phone != null &&
                            master.phone!.trim().isNotEmpty)
                        ? formatUzbekPhoneMask(master.phone!)
                        : '—';

                    return Card(
                      key: ValueKey('master_card_${master.id}'),
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor: master.isActive
                                      ? colorScheme.primaryContainer
                                      : colorScheme.surfaceContainerHighest,
                                  child: Icon(
                                    Icons.engineering_outlined,
                                    color: master.isActive
                                        ? colorScheme.onPrimaryContainer
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        master.fullName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        phoneDisplay,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: statusColor,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              alignment: WrapAlignment.end,
                              children: [
                                TextButton.icon(
                                  key: ValueKey('master_edit_${master.id}'),
                                  onPressed: () => _openEditSheet(master),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Tahrirlash'),
                                ),
                                TextButton.icon(
                                  key: ValueKey('master_toggle_${master.id}'),
                                  onPressed: () => _toggleActive(master),
                                  style: TextButton.styleFrom(
                                    foregroundColor: master.isActive
                                        ? colorScheme.error
                                        : const Color(0xFF16A34A),
                                  ),
                                  icon: Icon(
                                    master.isActive
                                        ? Icons.pause_circle_outline
                                        : Icons.check_circle_outline,
                                    size: 18,
                                  ),
                                  label: Text(
                                    master.isActive
                                        ? 'Nofaol qilish'
                                        : 'Faollashtirish',
                                  ),
                                ),
                                TextButton.icon(
                                  key: ValueKey('master_delete_${master.id}'),
                                  onPressed: () => _deleteMaster(master),
                                  style: TextButton.styleFrom(
                                    foregroundColor: colorScheme.error,
                                  ),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                  label: const Text('O\'chirish'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        mapErrorToMessage(err),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => ref.invalidate(mastersProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Qayta urinish'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
