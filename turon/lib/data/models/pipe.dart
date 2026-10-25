import 'package:freezed_annotation/freezed_annotation.dart';
import 'work_status.dart';

part 'pipe.freezed.dart';
part 'pipe.g.dart';

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.parse(value);
  return 0;
}

/// `path` column: interior bend points as [[lat, lng], ...]; null = straight.
List<List<double>> _pathFromJson(Object? value) {
  if (value is! List) return const [];
  return [
    for (final p in value)
      if (p is List && p.length >= 2)
        [(p[0] as num).toDouble(), (p[1] as num).toDouble()],
  ];
}

Object? _pathToJson(List<List<double>> path) => path.isEmpty ? null : path;

double? _toNullableDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

@freezed
abstract class Pipe with _$Pipe {
  const Pipe._();

  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Pipe({
    required String id,
    required String code,
    @JsonKey(name: 'from_manhole_id') required String fromManholeId,
    @JsonKey(name: 'to_manhole_id') required String toManholeId,
    @JsonKey(name: 'diameter_mm') required int diameterMm,
    @JsonKey(name: 'length_auto_m', fromJson: _toDouble)
    @Default(0)
    double lengthAutoM,
    @JsonKey(name: 'length_manual_m', fromJson: _toNullableDouble)
    double? lengthManualM,
    @Default(WorkStatus.planned) WorkStatus status,
    @JsonKey(fromJson: _pathFromJson, toJson: _pathToJson)
    @Default([])
    List<List<double>> path,
    String? note,
    @JsonKey(name: 'created_by') String? createdBy,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _Pipe;

  factory Pipe.fromJson(Map<String, dynamic> json) => _$PipeFromJson(json);

  double get lengthM => lengthManualM ?? lengthAutoM;

  double get effectiveLengthM => lengthM;

  bool get isManual => lengthManualM != null;

  bool get isCurved => path.isNotEmpty;

  /// Bend points in the opposite flow direction (for swapping from/to).
  List<List<double>> get reversedPath => path.reversed.toList();
}
