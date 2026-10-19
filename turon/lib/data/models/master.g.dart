// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'master.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Master _$MasterFromJson(Map<String, dynamic> json) => _Master(
  id: json['id'] as String,
  fullName: json['full_name'] as String,
  phone: json['phone'] as String?,
  isActive: json['is_active'] as bool? ?? true,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$MasterToJson(_Master instance) => <String, dynamic>{
  'id': instance.id,
  'full_name': instance.fullName,
  'phone': instance.phone,
  'is_active': instance.isActive,
  'created_at': instance.createdAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};
