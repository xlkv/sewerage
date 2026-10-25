// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'section.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Section _$SectionFromJson(Map<String, dynamic> json) => _Section(
  id: json['id'] as String,
  name: json['name'] as String,
  note: json['note'] as String?,
  status:
      $enumDecodeNullable(_$WorkStatusEnumMap, json['status']) ??
      WorkStatus.planned,
  startDate: json['start_date'] == null
      ? null
      : DateTime.parse(json['start_date'] as String),
  endDate: json['end_date'] == null
      ? null
      : DateTime.parse(json['end_date'] as String),
  createdBy: json['created_by'] as String?,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$SectionToJson(_Section instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'note': instance.note,
  'status': _$WorkStatusEnumMap[instance.status]!,
  'start_date': instance.startDate?.toIso8601String(),
  'end_date': instance.endDate?.toIso8601String(),
  'created_by': instance.createdBy,
  'created_at': instance.createdAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};

const _$WorkStatusEnumMap = {
  WorkStatus.planned: 'planned',
  WorkStatus.inProgress: 'in_progress',
  WorkStatus.completed: 'completed',
};

_SectionFile _$SectionFileFromJson(Map<String, dynamic> json) => _SectionFile(
  id: json['id'] as String,
  sectionId: json['section_id'] as String,
  name: json['name'] as String,
  path: json['path'] as String,
  mime: json['mime'] as String?,
  sizeBytes: (json['size_bytes'] as num?)?.toInt(),
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$SectionFileToJson(_SectionFile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'section_id': instance.sectionId,
      'name': instance.name,
      'path': instance.path,
      'mime': instance.mime,
      'size_bytes': instance.sizeBytes,
      'created_at': instance.createdAt?.toIso8601String(),
    };
