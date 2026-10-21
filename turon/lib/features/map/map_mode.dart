import 'package:flutter/foundation.dart';

@immutable
sealed class MapMode {
  const MapMode();

  /// Banner text shown at the top of the map for the current mode (LLD 4.5).
  /// Returns null in [ViewMode].
  String? get bannerText => switch (this) {
    ViewMode() => null,
    AddManholeMode() => 'Kolodets joyini xaritadan tanlang',
    AddPipeMode(fromManholeId: null) => '1-kolodetsni tanlang',
    AddPipeMode(fromManholeId: _?) => '2-kolodetsni tanlang',
    MoveManholeMode() => 'Kolodetsni yangi joyga suring \u2192 Saqlash',
  };
}

class ViewMode extends MapMode {
  const ViewMode();

  @override
  bool operator ==(Object other) => other is ViewMode;

  @override
  int get hashCode => (ViewMode).hashCode;

  @override
  String toString() => 'ViewMode()';
}

class AddManholeMode extends MapMode {
  final double? pendingLat;
  final double? pendingLng;

  const AddManholeMode({this.pendingLat, this.pendingLng});

  bool get hasCoordinate => pendingLat != null && pendingLng != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AddManholeMode &&
          other.pendingLat == pendingLat &&
          other.pendingLng == pendingLng;

  @override
  int get hashCode => Object.hash(AddManholeMode, pendingLat, pendingLng);

  @override
  String toString() =>
      'AddManholeMode(pendingLat: $pendingLat, pendingLng: $pendingLng)';
}

class AddPipeMode extends MapMode {
  final String? fromManholeId;
  final String? toManholeId;

  const AddPipeMode({this.fromManholeId, this.toManholeId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AddPipeMode &&
          other.fromManholeId == fromManholeId &&
          other.toManholeId == toManholeId;

  @override
  int get hashCode => Object.hash(AddPipeMode, fromManholeId, toManholeId);

  @override
  String toString() => 'AddPipeMode(from: $fromManholeId, to: $toManholeId)';
}

class MoveManholeMode extends MapMode {
  final String manholeId;
  final double newLat;
  final double newLng;

  const MoveManholeMode({
    required this.manholeId,
    required this.newLat,
    required this.newLng,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoveManholeMode &&
          other.manholeId == manholeId &&
          other.newLat == newLat &&
          other.newLng == newLng;

  @override
  int get hashCode => Object.hash(MoveManholeMode, manholeId, newLat, newLng);

  @override
  String toString() =>
      'MoveManholeMode(manholeId: $manholeId, newLat: $newLat, newLng: $newLng)';
}

@immutable
sealed class Selection {
  const Selection();
}

class ManholeSelection extends Selection {
  final String id;
  const ManholeSelection(this.id);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ManholeSelection && other.id == id;

  @override
  int get hashCode => Object.hash(ManholeSelection, id);

  @override
  String toString() => 'ManholeSelection($id)';
}

class PipeSelection extends Selection {
  final String id;
  const PipeSelection(this.id);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PipeSelection && other.id == id;

  @override
  int get hashCode => Object.hash(PipeSelection, id);

  @override
  String toString() => 'PipeSelection($id)';
}

/// Active form opened from a map mode or details card.
@immutable
sealed class ActiveForm {
  const ActiveForm();
}

class CreateManholeForm extends ActiveForm {
  final double lat;
  final double lng;

  const CreateManholeForm({required this.lat, required this.lng});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateManholeForm && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(CreateManholeForm, lat, lng);

  @override
  String toString() => 'CreateManholeForm(lat: $lat, lng: $lng)';
}

class EditManholeForm extends ActiveForm {
  final String manholeId;

  const EditManholeForm({required this.manholeId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EditManholeForm && other.manholeId == manholeId;

  @override
  int get hashCode => Object.hash(EditManholeForm, manholeId);

  @override
  String toString() => 'EditManholeForm(manholeId: $manholeId)';
}

class CreatePipeForm extends ActiveForm {
  final String fromManholeId;
  final String toManholeId;

  const CreatePipeForm({
    required this.fromManholeId,
    required this.toManholeId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreatePipeForm &&
          other.fromManholeId == fromManholeId &&
          other.toManholeId == toManholeId;

  @override
  int get hashCode => Object.hash(CreatePipeForm, fromManholeId, toManholeId);

  @override
  String toString() => 'CreatePipeForm(from: $fromManholeId, to: $toManholeId)';
}

class EditPipeForm extends ActiveForm {
  final String pipeId;

  const EditPipeForm({required this.pipeId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is EditPipeForm && other.pipeId == pipeId;

  @override
  int get hashCode => Object.hash(EditPipeForm, pipeId);

  @override
  String toString() => 'EditPipeForm(pipeId: $pipeId)';
}
