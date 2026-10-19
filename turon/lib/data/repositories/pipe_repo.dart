import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/geo_utils.dart';
import '../../core/optimistic_store.dart';
import '../models/manhole.dart';
import '../models/pipe.dart';
import '../models/work_status.dart';
import 'auth_repo.dart';

final pipeRepoProvider = Provider<PipeRepository>(
  (ref) => PipeRepository(ref.watch(supabaseProvider)),
);

final pipesProvider = StreamProvider<Map<String, Pipe>>((ref) {
  ref.watch(authSessionProvider);
  return ref.watch(pipeRepoProvider).watchAll();
});

class PipeRepository {
  final SupabaseClient _client;
  final OptimisticEntityStore<Pipe> _store = OptimisticEntityStore<Pipe>(
    getId: (p) => p.id,
    getUpdatedAt: (p) => p.updatedAt,
  );

  PipeRepository(this._client);

  Stream<Map<String, Pipe>> watchAll() {
    return _store.watchWithRemote(
      () => _client
          .from('pipes')
          .stream(primaryKey: ['id'])
          .map((rows) => rows.map(Pipe.fromJson)),
    );
  }

  Future<List<Pipe>> fetchAll() async {
    final rows = await _client
        .from('pipes')
        .select()
        .order('created_at');
    final list = (rows as List<dynamic>)
        .map((r) => Pipe.fromJson(r as Map<String, dynamic>))
        .toList();
    _store.applyRemote(list);
    return list;
  }

  Future<Pipe> create({
    required String fromManholeId,
    required String toManholeId,
    required int diameterMm,
    String? code,
    double? lengthManualM,
    WorkStatus status = WorkStatus.planned,
    String? note,
  }) async {
    final payload = <String, dynamic>{
      'from_manhole_id': fromManholeId,
      'to_manhole_id': toManholeId,
      'diameter_mm': diameterMm,
      'status': status.toJsonValue(),
      'length_manual_m': ?lengthManualM,
    };
    if (code != null && code.trim().isNotEmpty) {
      payload['code'] = code.trim();
    }
    if (note != null && note.trim().isNotEmpty) {
      payload['note'] = note.trim();
    }

    final row = await _client.from('pipes').insert(payload).select().single();
    final created = Pipe.fromJson(row);
    _store.upsert(created);
    return created;
  }

  Future<Pipe> update(
    String id, {
    String? code,
    String? fromManholeId,
    String? toManholeId,
    int? diameterMm,
    double? lengthManualM,
    bool clearManualLength = false,
    WorkStatus? status,
    String? note,
    bool clearNote = false,
  }) async {
    // Never send length_auto_m on update (revoked at column level per LLD 1.3)
    final payload = <String, dynamic>{
      'from_manhole_id': ?fromManholeId,
      'to_manhole_id': ?toManholeId,
      'diameter_mm': ?diameterMm,
    };
    if (code != null && code.trim().isNotEmpty) {
      payload['code'] = code.trim();
    }
    if (clearManualLength) {
      payload['length_manual_m'] = null;
    } else if (lengthManualM != null) {
      payload['length_manual_m'] = lengthManualM;
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
        .from('pipes')
        .update(payload)
        .eq('id', id)
        .select()
        .single();
    final updated = Pipe.fromJson(row);
    _store.upsert(updated);
    return updated;
  }

  Future<void> delete(String id) async {
    final rows = await _client
        .from('pipes')
        .delete()
        .eq('id', id)
        .select('id');
    ensureDeletedRowsAffected(rows);
    _store.remove(id);
  }

  /// Optimistically recalculates `lengthAutoM` for pipes connected to a moved manhole.
  void recalculateForMovedManhole(
    Manhole moved,
    Map<String, Manhole> allManholes,
  ) {
    final manholes = {...allManholes, moved.id: moved};
    final now = DateTime.now().toUtc();
    final updatedPipes = <Pipe>[];
    for (final pipe in _store.currentMap.values) {
      if (pipe.fromManholeId == moved.id || pipe.toManholeId == moved.id) {
        final from = manholes[pipe.fromManholeId];
        final to = manholes[pipe.toManholeId];
        if (from != null && to != null) {
          final newAuto = GeoUtils.spheroidMetersRounded(
            from.lat,
            from.lng,
            to.lat,
            to.lng,
          );
          updatedPipes.add(
            pipe.copyWith(lengthAutoM: newAuto, updatedAt: now),
          );
        }
      }
    }
    if (updatedPipes.isNotEmpty) {
      _store.upsertAll(updatedPipes);
    }
  }
}
