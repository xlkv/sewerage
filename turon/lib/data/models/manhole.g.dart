// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'manhole.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Manhole _$ManholeFromJson(Map<String, dynamic> json) => _Manhole(
  id: json['id'] as String,
  code: json['code'] as String,
  lat: _toDouble(json['lat']),
  lng: _toDouble(json['lng']),
  heightM: _toNullableDouble(json['height_m']),
  diameterM: _toNullableDouble(json['diameter_m']),
  groundElev: _toNullableDouble(json['ground_elev']),
  invertElev: _toNullableDouble(json['invert_elev']),
  masterId: json['master_id'] as String?,
  status:
      $enumDecodeNullable(_$WorkStatusEnumMap, json['status']) ??
      WorkStatus.planned,
  note: json['note'] as String?,
  createdBy: json['created_by'] as String?,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$ManholeToJson(_Manhole instance) => <String, dynamic>{
  'id': instance.id,
  'code': instance.code,
  'lat': instance.lat,
  'lng': instance.lng,
  'height_m': instance.heightM,
  'diameter_m': instance.diameterM,
  'ground_elev': instance.groundElev,
  'invert_elev': instance.invertElev,
  'master_id': instance.masterId,
  'status': _$WorkStatusEnumMap[instance.status]!,
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
