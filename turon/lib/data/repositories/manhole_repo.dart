import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/optimistic_store.dart';
import '../models/manhole.dart';
import '../models/work_status.dart';
import 'auth_repo.dart';

final manholeRepoProvider = Provider<ManholeRepository>(
  (ref) => ManholeRepository(ref.watch(supabaseProvider)),
);

final manholesProvider = StreamProvider<Map<String, Manhole>>((ref) {
  ref.watch(authSessionProvider);
  return ref.watch(manholeRepoProvider).watchAll();
});

class ManholeRepository {
  final SupabaseClient _client;
  final OptimisticEntityStore<Manhole> _store = OptimisticEntityStore<Manhole>(
    getId: (m) => m.id,
    getUpdatedAt: (m) => m.updatedAt,
  );

  ManholeRepository(this._client);

  static const String _columns =
      'id, code, lat, lng, height_m, diameter_m, ground_elev, invert_elev, master_id, status, note, created_by, created_at, updated_at';

  Stream<Map<String, Manhole>> watchAll() {
    return _store.watchWithRemote(
      () => _client
          .from('manholes')
          .stream(primaryKey: ['id'])
          .map((rows) => rows.map(Manhole.fromJson)),
    );
  }

  Future<List<Manhole>> fetchAll() async {
    final rows = await _client
        .from('manholes')
        .select(_columns)
        .order('created_at');
    final list = (rows as List<dynamic>)
        .map((r) => Manhole.fromJson(r as Map<String, dynamic>))
        .toList();
    _store.applyRemote(list);
    return list;
  }

  /// Loads one manhole into the local store (e.g. one created by an RPC,
  /// before realtime delivers it).
  Future<Manhole> fetchOne(String id) async {
    final row = await _client
        .from('manholes')
        .select(_columns)
        .eq('id', id)
        .single();
    final m = Manhole.fromJson(row);
    _store.upsert(m);
    return m;
  }

  Future<Manhole> create({
    required double lat,
    required double lng,
    String? code,
    double? heightM,
    double? diameterM,
    double? groundElev,
    double? invertElev,
    String? masterId,
    WorkStatus status = WorkStatus.planned,
    String? note,
  }) async {
    final payload = <String, dynamic>{
      'lat': lat,
      'lng': lng,
      'status': status.toJsonValue(),
      'height_m': ?heightM,
      'diameter_m': ?diameterM,
      'ground_elev': ?groundElev,
      'invert_elev': ?invertElev,
      'master_id': ?masterId,
    };
    if (code != null && code.trim().isNotEmpty) {
      payload['code'] = code.trim();
    }
    if (note != null && note.trim().isNotEmpty) {
      payload['note'] = note.trim();
    }

    final row = await _client
        .from('manholes')
        .insert(payload)
        .select(_columns)
        .single();
    final created = Manhole.fromJson(row);
    _store.upsert(created);
    return created;
  }

  Future<Manhole> update(
    String id, {
    String? code,
    double? lat,
    double? lng,
    double? heightM,
    bool clearHeight = false,
    double? diameterM,
    bool clearDiameter = false,
    double? groundElev,
    bool clearGroundElev = false,
    double? invertElev,
    bool clearInvertElev = false,
    String? masterId,
    bool clearMaster = false,
    WorkStatus? status,
    String? note,
    bool clearNote = false,
  }) async {
    final payload = <String, dynamic>{
      'lat': ?lat,
      'lng': ?lng,
    };
    if (code != null && code.trim().isNotEmpty) {
      payload['code'] = code.trim();
    }
    if (clearHeight) {
      payload['height_m'] = null;
    } else if (heightM != null) {
      payload['height_m'] = heightM;
    }
    if (clearDiameter) {
      payload['diameter_m'] = null;
    } else if (diameterM != null) {
      payload['diameter_m'] = diameterM;
    }
    if (clearGroundElev) {
      payload['ground_elev'] = null;
    } else if (groundElev != null) {
      payload['ground_elev'] = groundElev;
    }
    if (clearInvertElev) {
      payload['invert_elev'] = null;
    } else if (invertElev != null) {
      payload['invert_elev'] = invertElev;
    }
    if (clearMaster) {
      payload['master_id'] = null;
    } else if (masterId != null) {
      payload['master_id'] = masterId;
    }
    if (status != null) {
      payload['status'] = status.toJsonValue();
    }
    if (clearNote) {
      payload['note'] = null;
    } else if (note != null) {
      payload['note'] = note.trim();
    }

    final row = await _client
        .from('manholes')
        .update(payload)
        .eq('id', id)
        .select(_columns)
        .single();
    final updated = Manhole.fromJson(row);
    _store.upsert(updated);
    return updated;
  }

  Future<Manhole> move(
    String id, {
    required double lat,
    required double lng,
  }) async {
    final row = await _client
        .from('manholes')
        .update({'lat': lat, 'lng': lng})
        .eq('id', id)
        .select(_columns)
        .single();
    final updated = Manhole.fromJson(row);
    _store.upsert(updated);
    return updated;
  }

  Future<void> delete(String id) async {
    final rows = await _client
        .from('manholes')
        .delete()
        .eq('id', id)
        .select('id');
    ensureDeletedRowsAffected(rows);
    _store.remove(id);
  }

  /// Optimistically clears `masterId` on local manholes when a master is deleted
  /// (`ON DELETE SET NULL` in DB).
  void clearMasterLocally(String masterId) {
    final toUpdate = <Manhole>[];
    final now = DateTime.now().toUtc();
    for (final m in _store.currentMap.values) {
      if (m.masterId == masterId) {
        toUpdate.add(m.copyWith(masterId: null, updatedAt: now));
      }
    }
    if (toUpdate.isNotEmpty) {
      _store.upsertAll(toUpdate);
    }
  }
}
