import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth_utils.dart';
import '../../core/errors.dart';
import '../models/profile.dart';

final supabaseProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final authRepoProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseProvider)),
);

final authSessionProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(authRepoProvider).onAuthStateChange,
);

final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  ref.watch(authSessionProvider);
  return ref.watch(authRepoProvider).getCurrentProfile();
});

class AuthRepository {
  final SupabaseClient _client;

  const AuthRepository(this._client);

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  User? get currentUser => _client.auth.currentUser;

  Session? get currentSession => _client.auth.currentSession;

  Future<Profile> signIn({
    required String phone,
    required String pin,
  }) async {
    final normalized = normalizePhone(phone);
    if (normalized == null) {
      throw const AppException('Telefon raqam noto\'g\'ri');
    }
    if (!isValidPin(pin)) {
      throw const AppException('PIN kod 5 ta raqamdan iborat bo\'lishi kerak');
    }

    final response = await _client.auth.signInWithPassword(
      email: pseudoEmail(normalized),
      password: derivePassword(pin.trim()),
    );

    final user = response.user;
    if (user == null) {
      throw const AppException('Telefon yoki parol noto\'g\'ri');
    }

    final row = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (row == null) {
      await _client.auth.signOut();
      throw const AppException('Foydalanuvchi profili topilmadi');
    }

    final profile = Profile.fromJson(row);
    if (!profile.isActive) {
      await _client.auth.signOut();
      throw const AppException('Hisobingiz bloklangan. Admin bilan bog\'laning');
    }

    return profile;
  }

  Future<Profile?> getCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final row = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (row == null) return null;

    final profile = Profile.fromJson(row);
    if (!profile.isActive) {
      await _client.auth.signOut();
      return null;
    }
    return profile;
  }

  Future<void> changePin({
    required String oldPin,
    required String newPin,
  }) async {
    if (!isValidPin(oldPin) || !isValidPin(newPin)) {
      throw const AppException('PIN kod 5 ta raqamdan iborat bo\'lishi kerak');
    }

    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AppException('Tizimga kirmagansiz');
    }

    String? email = user.email;
    if (email == null || email.isEmpty) {
      final profile = await getCurrentProfile();
      if (profile == null) {
        throw const AppException('Foydalanuvchi profili topilmadi');
      }
      email = pseudoEmail(profile.phone);
    }

    await _client.auth.signInWithPassword(
      email: email,
      password: derivePassword(oldPin.trim()),
    );

    await _client.auth.updateUser(
      UserAttributes(password: derivePassword(newPin.trim())),
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
