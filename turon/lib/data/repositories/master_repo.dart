import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth_utils.dart';
import '../../core/errors.dart';
import '../../core/optimistic_store.dart';
import '../models/master.dart';
import 'auth_repo.dart';

final masterRepoProvider = Provider<MasterRepository>(
  (ref) => MasterRepository(ref.watch(supabaseProvider)),
);

final mastersProvider = StreamProvider<List<Master>>((ref) {
  ref.watch(authSessionProvider);
  return ref.watch(masterRepoProvider).watchAll();
});

class MasterRepository {
  final SupabaseClient _client;
  final OptimisticEntityStore<Master> _store = OptimisticEntityStore<Master>(
    getId: (m) => m.id,
  );

  MasterRepository(this._client);

  Stream<List<Master>> watchAll() {
    return _store
        .watchWithRemote(
          () => _client
              .from('masters')
              .stream(primaryKey: ['id'])
              .order('full_name', ascending: true)
              .map((rows) => rows.map(Master.fromJson)),
        )
        .map((map) {
          final list = map.values.toList();
          list.sort(
            (a, b) =>
                a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
          );
          return list;
        });
  }

  Future<List<Master>> fetchAll() async {
    final rows = await _client
        .from('masters')
        .select()
        .order('full_name', ascending: true);
    final list = (rows as List<dynamic>)
        .map((r) => Master.fromJson(r as Map<String, dynamic>))
        .toList();
    _store.applyRemote(list);
    return list;
  }

  Future<Master> create({
    required String fullName,
    String? phone,
    bool isActive = true,
  }) async {
    String? normalizedPhone;
    if (phone != null && phone.trim().isNotEmpty) {
      normalizedPhone = normalizePhone(phone);
      if (normalizedPhone == null) {
        throw const AppException('Telefon raqam noto\'g\'ri');
      }
    }

    final row = await _client
        .from('masters')
        .insert({
          'full_name': fullName.trim(),
          'phone': normalizedPhone,
          'is_active': isActive,
        })
        .select()
        .single();
    final created = Master.fromJson(row);
    _store.upsert(created);
    return created;
  }

  Future<Master> update(
    String id, {
    String? fullName,
    String? phone,
    bool clearPhone = false,
    bool? isActive,
  }) async {
    String? normalizedPhone;
    if (!clearPhone && phone != null && phone.trim().isNotEmpty) {
      normalizedPhone = normalizePhone(phone);
      if (normalizedPhone == null) {
        throw const AppException('Telefon raqam noto\'g\'ri');
      }
    }

    final payload = <String, dynamic>{
      'is_active': ?isActive,
    };
    if (fullName != null) {
      payload['full_name'] = fullName.trim();
    }
    if (clearPhone) {
      payload['phone'] = null;
    } else if (normalizedPhone != null) {
      payload['phone'] = normalizedPhone;
    }

    final row = await _client
        .from('masters')
        .update(payload)
        .eq('id', id)
        .select()
        .single();
    final updated = Master.fromJson(row);
    _store.upsert(updated);
    return updated;
  }

  Future<void> delete(String id) async {
    final rows = await _client
        .from('masters')
        .delete()
        .eq('id', id)
        .select('id');
    ensureDeletedRowsAffected(rows);
    _store.remove(id);
  }
}
