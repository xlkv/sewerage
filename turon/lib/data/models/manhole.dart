import 'package:freezed_annotation/freezed_annotation.dart';
import 'work_status.dart';

part 'manhole.freezed.dart';
part 'manhole.g.dart';

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.parse(value);
  throw ArgumentError('Cannot convert $value to double');
}

double? _toNullableDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

@freezed
abstract class Manhole with _$Manhole {
  const Manhole._();

  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Manhole({
    required String id,
    required String code,
    @JsonKey(fromJson: _toDouble) required double lat,
    @JsonKey(fromJson: _toDouble) required double lng,
    @JsonKey(name: 'height_m', fromJson: _toNullableDouble) double? heightM,
    @JsonKey(name: 'diameter_m', fromJson: _toNullableDouble) double? diameterM,
    @JsonKey(name: 'master_id') String? masterId,
    @Default(WorkStatus.planned) WorkStatus status,
    String? note,
    @JsonKey(name: 'created_by') String? createdBy,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _Manhole;

  factory Manhole.fromJson(Map<String, dynamic> json) =>
      _$ManholeFromJson(json);
}
