import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth_utils.dart';
import '../../core/errors.dart';
import '../models/profile.dart';
import 'auth_repo.dart';

final adminUsersRepoProvider = Provider<AdminUsersRepository>(
  (ref) => AdminUsersRepository(ref.watch(supabaseProvider)),
);

final adminUsersProvider = FutureProvider<List<Profile>>((ref) async {
  ref.watch(authSessionProvider);
  return ref.watch(adminUsersRepoProvider).fetchUsers();
});

class AdminUsersRepository {
  final SupabaseClient _client;

  const AdminUsersRepository(this._client);

  Future<List<Profile>> fetchUsers() async {
    final rows = await _client
        .from('profiles')
        .select()
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((r) => Profile.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<String> createUser({
    required String phone,
    required String fullName,
    required String pin,
    required AppRole role,
  }) async {
    final normalized = normalizePhone(phone);
    if (normalized == null) {
      throw const AppException('Telefon raqam noto\'g\'ri');
    }
    if (!isValidPin(pin)) {
      throw const AppException('PIN kod 5 ta raqamdan iborat bo\'lishi kerak');
    }

    final response = await _client.functions.invoke(
      'admin-users',
      body: {
        'action': 'create',
        'phone': normalized,
        'full_name': fullName.trim(),
        'pin': pin.trim(),
        'role': role.name,
      },
    );

    final data = response.data;
    if (data is Map && data['user_id'] is String) {
      return data['user_id'] as String;
    }
    throw const AppException('Foydalanuvchi yaratishda xatolik');
  }

  Future<void> resetPin({
    required String userId,
    required String pin,
  }) async {
    if (!isValidPin(pin)) {
      throw const AppException('PIN kod 5 ta raqamdan iborat bo\'lishi kerak');
    }

    await _client.functions.invoke(
      'admin-users',
      body: {
        'action': 'reset_pin',
        'user_id': userId,
        'pin': pin.trim(),
      },
    );
  }

  Future<void> setActive({
    required String userId,
    required bool isActive,
  }) async {
    await _client.functions.invoke(
      'admin-users',
      body: {
        'action': 'set_active',
        'user_id': userId,
        'is_active': isActive,
      },
    );
  }

  Future<void> updateUser({
    required String userId,
    String? fullName,
    AppRole? role,
  }) async {
    await _client.functions.invoke(
      'admin-users',
      body: {
        'action': 'update',
        'user_id': userId,
        if (fullName != null) 'full_name': fullName.trim(),
        if (role != null) 'role': role.name,
      },
    );
  }
}
