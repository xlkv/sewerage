// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pipe.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Pipe _$PipeFromJson(Map<String, dynamic> json) => _Pipe(
  id: json['id'] as String,
  code: json['code'] as String,
  fromManholeId: json['from_manhole_id'] as String,
  toManholeId: json['to_manhole_id'] as String,
  diameterMm: (json['diameter_mm'] as num).toInt(),
  lengthAutoM: json['length_auto_m'] == null
      ? 0
      : _toDouble(json['length_auto_m']),
  lengthManualM: _toNullableDouble(json['length_manual_m']),
  status:
      $enumDecodeNullable(_$WorkStatusEnumMap, json['status']) ??
      WorkStatus.planned,
  path: json['path'] == null ? const [] : _pathFromJson(json['path']),
  note: json['note'] as String?,
  createdBy: json['created_by'] as String?,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$PipeToJson(_Pipe instance) => <String, dynamic>{
  'id': instance.id,
  'code': instance.code,
  'from_manhole_id': instance.fromManholeId,
  'to_manhole_id': instance.toManholeId,
  'diameter_mm': instance.diameterMm,
  'length_auto_m': instance.lengthAutoM,
  'length_manual_m': instance.lengthManualM,
  'status': _$WorkStatusEnumMap[instance.status]!,
  'path': _pathToJson(instance.path),
  'note': instance.note,
  'created_by': instance.createdBy,
  'created_at': instance.createdAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};

const _$WorkStatusEnumMap = {
  WorkStatus.planned: 'planned',
  WorkStatus.inProgress: 'in_progress',
  WorkStatus.completed: 'completed',
};
