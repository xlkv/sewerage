import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth_utils.dart';
import '../../../core/errors.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/admin_users_repo.dart';
import '../../../data/repositories/auth_repo.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import 'user_form.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Profile> _filterUsers(List<Profile> users) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return users;
    final qDigits = q.replaceAll(RegExp(r'\D'), '');
    return users.where((u) {
      final matchesName = u.fullName.toLowerCase().contains(q);
      final matchesPhone =
          u.phone.toLowerCase().contains(q) ||
          formatUzbekPhoneMask(u.phone).toLowerCase().contains(q) ||
          (qDigits.isNotEmpty && u.phone.contains(qDigits));
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
      builder: (_) => const UserForm(),
    );
  }

  String? _resolveCurrentUserId() {
    final profileId = ref.watch(currentProfileProvider).asData?.value?.id;
    if (profileId != null) return profileId;
    try {
      return ref.read(authRepoProvider).currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openEditSheet(Profile user) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => UserForm(initialUser: user),
    );
  }

  Future<void> _openResetPinDialog(Profile user) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => UserResetPinDialog(user: user),
    );
  }

  Future<void> _toggleActive(Profile user) async {
    final currentUserId = _resolveCurrentUserId();
    if (currentUserId != null && currentUserId == user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O\'zingizni o\'zgartira olmaysiz')),
      );
      return;
    }

    final nextActive = !user.isActive;
    final confirmed = await showConfirmDialog(
      context,
      title: nextActive
          ? 'Foydalanuvchini faollashtirish'
          : 'Foydalanuvchini bloklash',
      message: nextActive
          ? '${user.fullName} hisobini qayta faollashtirmoqchimisiz?'
          : '${user.fullName} hisobini bloklamoqchimisiz?',
      confirmLabel: nextActive ? 'Faollashtirish' : 'Bloklash',
      isDestructive: !nextActive,
    );
    if (!confirmed || !mounted) return;

    try {
      await ref.read(adminUsersRepoProvider).setActive(
            userId: user.id,
            isActive: nextActive,
          );
      ref.invalidate(adminUsersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nextActive
                  ? '${user.fullName} faollashtirildi'
                  : '${user.fullName} bloklandi',
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

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersProvider);
    final currentUserId = _resolveCurrentUserId();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Foydalanuvchilar'),
        actions: [
          IconButton(
            tooltip: 'Yangilash',
            onPressed: () => ref.invalidate(adminUsersProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('users_add_fab'),
        onPressed: _openCreateSheet,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Qo\'shish'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              key: const ValueKey('users_search_field'),
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
            child: usersAsync.when(
              data: (users) {
                final filtered = _filterUsers(users);
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('Foydalanuvchilar topilmadi'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final user = filtered[index];
                    final isAdmin = user.role == AppRole.admin;
                    final roleLabel = isAdmin ? 'Admin' : 'Xodim';
                    final statusLabel = user.isActive ? 'Faol' : 'Bloklangan';
                    final statusColor = user.isActive
                        ? const Color(0xFF16A34A)
                        : colorScheme.error;

                    return Card(
                      key: ValueKey('user_card_${user.id}'),
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
                                  backgroundColor: isAdmin
                                      ? colorScheme.primaryContainer
                                      : colorScheme.secondaryContainer,
                                  child: Icon(
                                    isAdmin
                                        ? Icons.admin_panel_settings_outlined
                                        : Icons.person_outline,
                                    color: isAdmin
                                        ? colorScheme.onPrimaryContainer
                                        : colorScheme.onSecondaryContainer,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.fullName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        formatUzbekPhoneMask(user.phone),
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
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isAdmin
                                            ? colorScheme.primaryContainer
                                            : colorScheme
                                                  .surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        roleLabel,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: isAdmin
                                                  ? colorScheme
                                                        .onPrimaryContainer
                                                  : colorScheme
                                                        .onSurfaceVariant,
                                            ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(
                                          alpha: 0.14,
                                        ),
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
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              alignment: WrapAlignment.end,
                              children: [
                                TextButton.icon(
                                  key: ValueKey('user_edit_${user.id}'),
                                  onPressed: () => _openEditSheet(user),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Tahrirlash'),
                                ),
                                TextButton.icon(
                                  key: ValueKey('user_reset_pin_${user.id}'),
                                  onPressed: () => _openResetPinDialog(user),
                                  icon: const Icon(
                                    Icons.lock_reset_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('PIN tiklash'),
                                ),
                                if (currentUserId == null ||
                                    user.id != currentUserId)
                                  TextButton.icon(
                                    key: ValueKey('user_toggle_${user.id}'),
                                    onPressed: () => _toggleActive(user),
                                    style: TextButton.styleFrom(
                                      foregroundColor: user.isActive
                                          ? colorScheme.error
                                          : const Color(0xFF16A34A),
                                    ),
                                    icon: Icon(
                                      user.isActive
                                          ? Icons.block_outlined
                                          : Icons.check_circle_outline,
                                      size: 18,
                                    ),
                                    label: Text(
                                      user.isActive
                                          ? 'Bloklash'
                                          : 'Faollashtirish',
                                    ),
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
                        onPressed: () => ref.invalidate(adminUsersProvider),
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
