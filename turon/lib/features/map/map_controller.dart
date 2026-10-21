import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/pipe.dart';
import '../../data/models/work_status.dart';
import 'map_mode.dart';

enum MapLayer { scheme, satellite }

@immutable
class MapState {
  final MapMode mode;
  final Selection? selection;
  final ActiveForm? activeForm;
  final String? snackbarMessage;

  const MapState({
    this.mode = const ViewMode(),
    this.selection,
    this.activeForm,
    this.snackbarMessage,
  });

  static const _unset = Object();

  MapState copyWith({
    MapMode? mode,
    Object? selection = _unset,
    Object? activeForm = _unset,
    Object? snackbarMessage = _unset,
  }) {
    return MapState(
      mode: mode ?? this.mode,
      selection: identical(selection, _unset)
          ? this.selection
          : selection as Selection?,
      activeForm: identical(activeForm, _unset)
          ? this.activeForm
          : activeForm as ActiveForm?,
      snackbarMessage: identical(snackbarMessage, _unset)
          ? this.snackbarMessage
          : snackbarMessage as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapState &&
          other.mode == mode &&
          other.selection == selection &&
          other.activeForm == activeForm &&
          other.snackbarMessage == snackbarMessage;

  @override
  int get hashCode =>
      Object.hash(MapState, mode, selection, activeForm, snackbarMessage);
}

class MapController extends Notifier<MapState> {
  @override
  MapState build() => const MapState();

  static const String duplicatePipeMessage =
      'Bu kolodetslar allaqachon ulangan';

  /// Checks whether two manholes already have a connecting pipe in either direction.
  static bool hasPipeBetween(
    Iterable<Pipe> pipes,
    String manholeA,
    String manholeB,
  ) {
    for (final p in pipes) {
      final sameDir = p.fromManholeId == manholeA && p.toManholeId == manholeB;
      final reverseDir =
          p.fromManholeId == manholeB && p.toManholeId == manholeA;
      if (sameDir || reverseDir) return true;
    }
    return false;
  }

  void setMode(MapMode mode) {
    state = state.copyWith(mode: mode, activeForm: null, snackbarMessage: null);
  }

  void select(Selection? selection) {
    state = state.copyWith(
      selection: selection,
      activeForm: null,
      snackbarMessage: null,
    );
  }

  void clearSelection() {
    state = state.copyWith(
      selection: null,
      activeForm: null,
      snackbarMessage: null,
    );
  }

  void clearSnackbar() {
    if (state.snackbarMessage != null) {
      state = state.copyWith(snackbarMessage: null);
    }
  }

  /// Admin taps "Kolodets": View -> AddManhole.
  void startAddManhole({bool isAdmin = true}) {
    if (!isAdmin) return;
    state = const MapState(mode: AddManholeMode());
  }

  /// Admin taps "Quvur": View -> AddPipe(from: null).
  void startAddPipe({bool isAdmin = true}) {
    if (!isAdmin) return;
    state = const MapState(mode: AddPipeMode());
  }

  /// Admin taps "Joyini o'zgartirish" in Manhole details: View -> MoveManhole(id, lat, lng).
  void startMoveManhole(
    String manholeId, {
    required double initialLat,
    required double initialLng,
    bool isAdmin = true,
  }) {
    if (!isAdmin) return;
    state = MapState(
      mode: MoveManholeMode(
        manholeId: manholeId,
        newLat: initialLat,
        newLng: initialLng,
      ),
      selection: ManholeSelection(manholeId),
    );
  }

  /// Updates the pending coordinates of the manhole being moved.
  void updateMoveManholePosition(double newLat, double newLng) {
    final current = state.mode;
    if (current is MoveManholeMode) {
      state = state.copyWith(
        mode: MoveManholeMode(
          manholeId: current.manholeId,
          newLat: newLat,
          newLng: newLng,
        ),
      );
    }
  }

  /// Completes MoveManhole after saving to repository -> View.
  void completeMoveManhole() {
    final current = state.mode;
    final selected = current is MoveManholeMode
        ? ManholeSelection(current.manholeId)
        : state.selection;
    state = MapState(mode: const ViewMode(), selection: selected);
  }

  /// Handles tapping on empty map at (lat, lng) according to LLD 4.5.
  void onMapTap(double lat, double lng) {
    switch (state.mode) {
      case ViewMode():
        clearSelection();
      case AddManholeMode():
        state = state.copyWith(
          mode: AddManholeMode(pendingLat: lat, pendingLng: lng),
          activeForm: CreateManholeForm(lat: lat, lng: lng),
          snackbarMessage: null,
        );
      case AddPipeMode():
        // Tapping empty map in AddPipe keeps waiting for manhole tap.
        break;
      case MoveManholeMode(:final manholeId):
        // Allow tapping a point on map in MoveManhole mode as well as dragging.
        state = state.copyWith(
          mode: MoveManholeMode(manholeId: manholeId, newLat: lat, newLng: lng),
        );
    }
  }

  /// Handles tapping a Manhole placemark according to LLD 4.5.
  void onManholeTap(
    String manholeId, {
    Iterable<Pipe> existingPipes = const [],
  }) {
    switch (state.mode) {
      case ViewMode():
        state = state.copyWith(
          selection: ManholeSelection(manholeId),
          activeForm: null,
          snackbarMessage: null,
        );
      case AddPipeMode(fromManholeId: null):
        state = state.copyWith(
          mode: AddPipeMode(fromManholeId: manholeId),
          activeForm: null,
          snackbarMessage: null,
        );
      case AddPipeMode(fromManholeId: final fromId?):
        if (fromId == manholeId) {
          // Tap same manhole a -> AddPipe(from: null) (deselect)
          state = state.copyWith(
            mode: const AddPipeMode(fromManholeId: null),
            activeForm: null,
            snackbarMessage: null,
          );
        } else if (hasPipeBetween(existingPipes, fromId, manholeId)) {
          // Pipe already exists between a and b -> snackbar, stay in AddPipe(a)
          state = state.copyWith(
            mode: AddPipeMode(fromManholeId: fromId),
            activeForm: null,
            snackbarMessage: duplicatePipeMessage,
          );
        } else {
          // Valid b -> open Pipe form (from=a, to=b)
          state = state.copyWith(
            mode: AddPipeMode(fromManholeId: fromId, toManholeId: manholeId),
            activeForm: CreatePipeForm(
              fromManholeId: fromId,
              toManholeId: manholeId,
            ),
            snackbarMessage: null,
          );
        }
      case AddManholeMode():
      case MoveManholeMode():
        break;
    }
  }

  /// Handles tapping a Pipe polyline or arrow according to LLD 4.5.
  void onPipeTap(String pipeId) {
    if (state.mode is ViewMode) {
      state = state.copyWith(
        selection: PipeSelection(pipeId),
        activeForm: null,
        snackbarMessage: null,
      );
    }
  }

  /// Opens edit form for a manhole (admin only).
  void openEditManholeForm(String manholeId, {bool isAdmin = true}) {
    if (!isAdmin) return;
    state = state.copyWith(
      mode: const ViewMode(),
      selection: ManholeSelection(manholeId),
      activeForm: EditManholeForm(manholeId: manholeId),
      snackbarMessage: null,
    );
  }

  /// Opens edit form for a pipe (admin only).
  void openEditPipeForm(String pipeId, {bool isAdmin = true}) {
    if (!isAdmin) return;
    state = state.copyWith(
      mode: const ViewMode(),
      selection: PipeSelection(pipeId),
      activeForm: EditPipeForm(pipeId: pipeId),
      snackbarMessage: null,
    );
  }

  /// Closes only the active form (e.g. if user cancels form); if in AddManhole or AddPipe,
  /// transitions back to ViewMode as specified in LLD 4.5.
  void closeForm() {
    if (state.mode is! ViewMode) {
      resetToView(clearSelection: true);
    } else {
      state = state.copyWith(activeForm: null, snackbarMessage: null);
    }
  }

  /// Called after a Manhole or Pipe form saves successfully -> ViewMode.
  void onFormSaved({Selection? selection}) {
    state = MapState(
      mode: const ViewMode(),
      selection: selection ?? state.selection,
    );
  }

  /// Cancels any active mode or form ("Bekor qilish" or system Back) -> ViewMode.
  void cancelMode() {
    resetToView(clearSelection: true);
  }

  void resetToView({bool clearSelection = false}) {
    state = MapState(
      mode: const ViewMode(),
      selection: clearSelection ? null : state.selection,
    );
  }
}

final mapControllerProvider = NotifierProvider<MapController, MapState>(
  MapController.new,
);

class StatusFilterNotifier extends Notifier<Set<WorkStatus>> {
  @override
  Set<WorkStatus> build() => WorkStatus.values.toSet();

  void toggle(WorkStatus status) {
    final next = Set<WorkStatus>.from(state);
    if (next.contains(status)) {
      next.remove(status);
    } else {
      next.add(status);
    }
    state = next;
  }

  void setStatuses(Set<WorkStatus> statuses) {
    state = Set<WorkStatus>.from(statuses);
  }

  void selectAll() {
    state = WorkStatus.values.toSet();
  }
}

final statusFilterProvider =
    NotifierProvider<StatusFilterNotifier, Set<WorkStatus>>(
      StatusFilterNotifier.new,
    );

class MapLayerNotifier extends Notifier<MapLayer> {
  @override
  MapLayer build() => MapLayer.scheme;

  void setLayer(MapLayer layer) {
    state = layer;
  }

  void toggle() {
    state = state == MapLayer.scheme ? MapLayer.satellite : MapLayer.scheme;
  }
}

final mapLayerProvider = NotifierProvider<MapLayerNotifier, MapLayer>(
  MapLayerNotifier.new,
);
