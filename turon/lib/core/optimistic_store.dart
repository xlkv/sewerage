import 'dart:async';

import 'errors.dart';

/// Verifies that a Supabase `.delete().eq('id', id).select()` returned at least
/// one deleted row; throws an [AppException] if 0 rows were affected (e.g. RLS
/// blocked the deletion or the record no longer exists).
void ensureDeletedRowsAffected(dynamic rows) {
  if (rows is! List || rows.isEmpty) {
    throw const AppException(
      'O\'chirish amalga oshmadi (ruxsat yo\'q yoki topilmadi)',
      code: 'delete_failed',
    );
  }
}

/// Manages optimistic local state merged idempotently with a remote realtime stream.
///
/// Guarantees:
/// 1. Local `upsert` / `remove` updates state and emits immediately without
///    waiting for the 3-5s Supabase realtime round-trip.
/// 2. Incoming realtime snapshots merge idempotently by entity ID (no duplicates).
/// 3. Locally deleted IDs stay removed even if a lagging realtime snapshot
///    still contains them.
class OptimisticEntityStore<T> {
  final String Function(T item) getId;
  final DateTime? Function(T item)? getUpdatedAt;

  final Map<String, T> _remote = {};
  final Map<String, T> _localUpserts = {};
  final Set<String> _localDeletedIds = {};
  bool _hasEmitted = false;

  final StreamController<Map<String, T>> _controller =
      StreamController<Map<String, T>>.broadcast();

  OptimisticEntityStore({
    required this.getId,
    this.getUpdatedAt,
  });

  bool get hasEmitted => _hasEmitted;

  Map<String, T> get currentMap {
    final merged = <String, T>{};
    for (final entry in _remote.entries) {
      if (!_localDeletedIds.contains(entry.key)) {
        merged[entry.key] = entry.value;
      }
    }
    for (final entry in _localUpserts.entries) {
      if (!_localDeletedIds.contains(entry.key)) {
        merged[entry.key] = entry.value;
      }
    }
    return Map<String, T>.unmodifiable(merged);
  }

  void upsert(T item) {
    final id = getId(item);
    _localDeletedIds.remove(id);
    _localUpserts[id] = item;
    _emit();
  }

  void upsertAll(Iterable<T> items) {
    var changed = false;
    for (final item in items) {
      final id = getId(item);
      _localDeletedIds.remove(id);
      _localUpserts[id] = item;
      changed = true;
    }
    if (changed) {
      _emit();
    }
  }

  void remove(String id) {
    _localDeletedIds.add(id);
    _localUpserts.remove(id);
    _remote.remove(id);
    _emit();
  }

  void applyRemote(Iterable<T> remoteItems) {
    final nextRemote = <String, T>{};
    for (final item in remoteItems) {
      final id = getId(item);
      nextRemote[id] = item;

      final localItem = _localUpserts[id];
      if (localItem != null) {
        final updatedAtFn = getUpdatedAt;
        if (updatedAtFn != null) {
          final remoteTs = updatedAtFn(item);
          final localTs = updatedAtFn(localItem);
          if (remoteTs != null &&
              localTs != null &&
              !remoteTs.isBefore(localTs)) {
            _localUpserts.remove(id);
          }
        } else if (item == localItem) {
          _localUpserts.remove(id);
        }
      }
    }
    // Clean up deleted IDs that are confirmed absent in the remote snapshot
    _localDeletedIds.removeWhere((deletedId) => !nextRemote.containsKey(deletedId));

    _remote
      ..clear()
      ..addAll(nextRemote);
    _emit();
  }

  void _emit() {
    _hasEmitted = true;
    if (!_controller.isClosed) {
      _controller.add(currentMap);
    }
  }

  Stream<Map<String, T>> watchWithRemote(
    Stream<Iterable<T>> Function() remoteStreamFactory,
  ) {
    late StreamController<Map<String, T>> out;
    StreamSubscription<Map<String, T>>? localSub;
    StreamSubscription<Iterable<T>>? remoteSub;

    out = StreamController<Map<String, T>>(
      onListen: () {
        if (_hasEmitted) {
          out.add(currentMap);
        }
        localSub = _controller.stream.listen(
          (map) {
            if (!out.isClosed) out.add(map);
          },
          onError: (Object e, StackTrace st) {
            if (!out.isClosed) out.addError(e, st);
          },
        );
        try {
          remoteSub = remoteStreamFactory().listen(
            applyRemote,
            onError: (Object e, StackTrace st) {
              if (!out.isClosed) out.addError(e, st);
            },
          );
        } catch (e, st) {
          if (!out.isClosed) out.addError(e, st);
        }
      },
      onCancel: () async {
        await localSub?.cancel();
        await remoteSub?.cancel();
      },
    );
    return out.stream;
  }
}
