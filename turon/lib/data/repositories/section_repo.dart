import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/section.dart';
import '../models/work_status.dart';
import 'auth_repo.dart';

final sectionRepoProvider = Provider<SectionRepository>(
  (ref) => SectionRepository(ref.watch(supabaseProvider)),
);

final sectionsProvider = StreamProvider<Map<String, Section>>((ref) {
  ref.watch(authSessionProvider);
  return ref.watch(sectionRepoProvider).watchSections();
});

/// Section id -> pipe ids.
final sectionPipesProvider = StreamProvider<Map<String, Set<String>>>((ref) {
  ref.watch(authSessionProvider);
  return ref
      .watch(sectionRepoProvider)
      .watchMembership('section_pipes', 'pipe_id');
});

/// Section id -> manhole ids.
final sectionManholesProvider = StreamProvider<Map<String, Set<String>>>((
  ref,
) {
  ref.watch(authSessionProvider);
  return ref
      .watch(sectionRepoProvider)
      .watchMembership('section_manholes', 'manhole_id');
});

final sectionFilesProvider = StreamProvider.family<List<SectionFile>, String>((
  ref,
  sectionId,
) {
  ref.watch(authSessionProvider);
  return ref.watch(sectionRepoProvider).watchFiles(sectionId);
});

class SectionRepository {
  static const String bucket = 'section-files';
  static const int maxFileBytes = 50 * 1024 * 1024;

  final SupabaseClient _client;

  SectionRepository(this._client);

  Stream<Map<String, Section>> watchSections() => _client
      .from('sections')
      .stream(primaryKey: ['id'])
      .map((rows) => {for (final r in rows) r['id'] as String: Section.fromJson(r)});

  Stream<Map<String, Set<String>>> watchMembership(
    String table,
    String column,
  ) => _client.from(table).stream(primaryKey: ['section_id', column]).map((
    rows,
  ) {
    final out = <String, Set<String>>{};
    for (final r in rows) {
      out.putIfAbsent(r['section_id'] as String, () => {}).add(
        r[column] as String,
      );
    }
    return out;
  });

  Stream<List<SectionFile>> watchFiles(String sectionId) => _client
      .from('section_files')
      .stream(primaryKey: ['id'])
      .eq('section_id', sectionId)
      .order('created_at')
      .map((rows) => rows.map(SectionFile.fromJson).toList());

  static String? _date(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-'
            '${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}';

  /// Creates or updates a section and replaces its membership.
  Future<String> save({
    String? id,
    required String name,
    String? note,
    required WorkStatus status,
    DateTime? startDate,
    DateTime? endDate,
    required Set<String> pipeIds,
    required Set<String> manholeIds,
  }) async {
    final payload = {
      'name': name.trim(),
      'note': (note?.trim().isEmpty ?? true) ? null : note!.trim(),
      'status': status.toJsonValue(),
      'start_date': _date(startDate),
      'end_date': _date(endDate),
    };
    final String sectionId;
    if (id == null) {
      final row = await _client
          .from('sections')
          .insert(payload)
          .select('id')
          .single();
      sectionId = row['id'] as String;
    } else {
      await _client.from('sections').update(payload).eq('id', id);
      sectionId = id;
      await _client.from('section_pipes').delete().eq('section_id', id);
      await _client.from('section_manholes').delete().eq('section_id', id);
    }
    if (pipeIds.isNotEmpty) {
      await _client.from('section_pipes').insert([
        for (final p in pipeIds) {'section_id': sectionId, 'pipe_id': p},
      ]);
    }
    if (manholeIds.isNotEmpty) {
      await _client.from('section_manholes').insert([
        for (final m in manholeIds) {'section_id': sectionId, 'manhole_id': m},
      ]);
    }
    return sectionId;
  }

  Future<void> updateStatus(String id, WorkStatus status) => _client
      .from('sections')
      .update({'status': status.toJsonValue()})
      .eq('id', id);

  /// Deletes the section, its storage objects and (by cascade) its rows.
  Future<void> delete(String id) async {
    final files = await _client
        .from('section_files')
        .select('path')
        .eq('section_id', id);
    final paths = [for (final f in files) f['path'] as String];
    if (paths.isNotEmpty) {
      await _client.storage.from(bucket).remove(paths);
    }
    await _client.from('sections').delete().eq('id', id);
  }

  Future<void> uploadFile({
    required String sectionId,
    required String name,
    required Uint8List bytes,
    required String mime,
  }) async {
    final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path =
        '$sectionId/${DateTime.now().millisecondsSinceEpoch}_$safe';
    await _client.storage
        .from(bucket)
        .uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime));
    try {
      await _client.from('section_files').insert({
        'section_id': sectionId,
        'name': name,
        'path': path,
        'mime': mime,
        'size_bytes': bytes.length,
      });
    } catch (_) {
      await _client.storage.from(bucket).remove([path]);
      rethrow;
    }
  }

  Future<void> deleteFile(SectionFile file) async {
    await _client.storage.from(bucket).remove([file.path]);
    await _client.from('section_files').delete().eq('id', file.id);
  }

  /// Short-lived link to view or download a file.
  Future<String> signedUrl(SectionFile file) =>
      _client.storage.from(bucket).createSignedUrl(file.path, 600);
}
