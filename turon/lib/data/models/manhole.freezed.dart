// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'manhole.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Manhole {

 String get id; String get code;@JsonKey(fromJson: _toDouble) double get lat;@JsonKey(fromJson: _toDouble) double get lng;@JsonKey(name: 'height_m', fromJson: _toNullableDouble) double? get heightM;@JsonKey(name: 'diameter_m', fromJson: _toNullableDouble) double? get diameterM;@JsonKey(name: 'master_id') String? get masterId; WorkStatus get status; String? get note;@JsonKey(name: 'created_by') String? get createdBy;@JsonKey(name: 'created_at') DateTime? get createdAt;@JsonKey(name: 'updated_at') DateTime? get updatedAt;
/// Create a copy of Manhole
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ManholeCopyWith<Manhole> get copyWith => _$ManholeCopyWithImpl<Manhole>(this as Manhole, _$identity);

  /// Serializes this Manhole to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Manhole&&(identical(other.id, id) || other.id == id)&&(identical(other.code, code) || other.code == code)&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.heightM, heightM) || other.heightM == heightM)&&(identical(other.diameterM, diameterM) || other.diameterM == diameterM)&&(identical(other.masterId, masterId) || other.masterId == masterId)&&(identical(other.status, status) || other.status == status)&&(identical(other.note, note) || other.note == note)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,code,lat,lng,heightM,diameterM,masterId,status,note,createdBy,createdAt,updatedAt);

@override
String toString() {
  return 'Manhole(id: $id, code: $code, lat: $lat, lng: $lng, heightM: $heightM, diameterM: $diameterM, masterId: $masterId, status: $status, note: $note, createdBy: $createdBy, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $ManholeCopyWith<$Res>  {
  factory $ManholeCopyWith(Manhole value, $Res Function(Manhole) _then) = _$ManholeCopyWithImpl;
@useResult
$Res call({
 String id, String code,@JsonKey(fromJson: _toDouble) double lat,@JsonKey(fromJson: _toDouble) double lng,@JsonKey(name: 'height_m', fromJson: _toNullableDouble) double? heightM,@JsonKey(name: 'diameter_m', fromJson: _toNullableDouble) double? diameterM,@JsonKey(name: 'master_id') String? masterId, WorkStatus status, String? note,@JsonKey(name: 'created_by') String? createdBy,@JsonKey(name: 'created_at') DateTime? createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt
});




}
/// @nodoc
class _$ManholeCopyWithImpl<$Res>
    implements $ManholeCopyWith<$Res> {
  _$ManholeCopyWithImpl(this._self, this._then);

  final Manhole _self;
  final $Res Function(Manhole) _then;

/// Create a copy of Manhole
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? code = null,Object? lat = null,Object? lng = null,Object? heightM = freezed,Object? diameterM = freezed,Object? masterId = freezed,Object? status = null,Object? note = freezed,Object? createdBy = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,lat: null == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double,lng: null == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double,heightM: freezed == heightM ? _self.heightM : heightM // ignore: cast_nullable_to_non_nullable
as double?,diameterM: freezed == diameterM ? _self.diameterM : diameterM // ignore: cast_nullable_to_non_nullable
as double?,masterId: freezed == masterId ? _self.masterId : masterId // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as WorkStatus,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,createdBy: freezed == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Manhole].
extension ManholePatterns on Manhole {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Manhole value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Manhole() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Manhole value)  $default,){
final _that = this;
switch (_that) {
case _Manhole():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Manhole value)?  $default,){
final _that = this;
switch (_that) {
case _Manhole() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String code, @JsonKey(fromJson: _toDouble)  double lat, @JsonKey(fromJson: _toDouble)  double lng, @JsonKey(name: 'height_m', fromJson: _toNullableDouble)  double? heightM, @JsonKey(name: 'diameter_m', fromJson: _toNullableDouble)  double? diameterM, @JsonKey(name: 'master_id')  String? masterId,  WorkStatus status,  String? note, @JsonKey(name: 'created_by')  String? createdBy, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Manhole() when $default != null:
return $default(_that.id,_that.code,_that.lat,_that.lng,_that.heightM,_that.diameterM,_that.masterId,_that.status,_that.note,_that.createdBy,_that.createdAt,_that.updatedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String code, @JsonKey(fromJson: _toDouble)  double lat, @JsonKey(fromJson: _toDouble)  double lng, @JsonKey(name: 'height_m', fromJson: _toNullableDouble)  double? heightM, @JsonKey(name: 'diameter_m', fromJson: _toNullableDouble)  double? diameterM, @JsonKey(name: 'master_id')  String? masterId,  WorkStatus status,  String? note, @JsonKey(name: 'created_by')  String? createdBy, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Manhole():
return $default(_that.id,_that.code,_that.lat,_that.lng,_that.heightM,_that.diameterM,_that.masterId,_that.status,_that.note,_that.createdBy,_that.createdAt,_that.updatedAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String code, @JsonKey(fromJson: _toDouble)  double lat, @JsonKey(fromJson: _toDouble)  double lng, @JsonKey(name: 'height_m', fromJson: _toNullableDouble)  double? heightM, @JsonKey(name: 'diameter_m', fromJson: _toNullableDouble)  double? diameterM, @JsonKey(name: 'master_id')  String? masterId,  WorkStatus status,  String? note, @JsonKey(name: 'created_by')  String? createdBy, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Manhole() when $default != null:
return $default(_that.id,_that.code,_that.lat,_that.lng,_that.heightM,_that.diameterM,_that.masterId,_that.status,_that.note,_that.createdBy,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _Manhole extends Manhole {
  const _Manhole({required this.id, required this.code, @JsonKey(fromJson: _toDouble) required this.lat, @JsonKey(fromJson: _toDouble) required this.lng, @JsonKey(name: 'height_m', fromJson: _toNullableDouble) this.heightM, @JsonKey(name: 'diameter_m', fromJson: _toNullableDouble) this.diameterM, @JsonKey(name: 'master_id') this.masterId, this.status = WorkStatus.planned, this.note, @JsonKey(name: 'created_by') this.createdBy, @JsonKey(name: 'created_at') this.createdAt, @JsonKey(name: 'updated_at') this.updatedAt}): super._();
  factory _Manhole.fromJson(Map<String, dynamic> json) => _$ManholeFromJson(json);

@override final  String id;
@override final  String code;
@override@JsonKey(fromJson: _toDouble) final  double lat;
@override@JsonKey(fromJson: _toDouble) final  double lng;
@override@JsonKey(name: 'height_m', fromJson: _toNullableDouble) final  double? heightM;
@override@JsonKey(name: 'diameter_m', fromJson: _toNullableDouble) final  double? diameterM;
@override@JsonKey(name: 'master_id') final  String? masterId;
@override@JsonKey() final  WorkStatus status;
@override final  String? note;
@override@JsonKey(name: 'created_by') final  String? createdBy;
@override@JsonKey(name: 'created_at') final  DateTime? createdAt;
@override@JsonKey(name: 'updated_at') final  DateTime? updatedAt;

/// Create a copy of Manhole
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ManholeCopyWith<_Manhole> get copyWith => __$ManholeCopyWithImpl<_Manhole>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ManholeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Manhole&&(identical(other.id, id) || other.id == id)&&(identical(other.code, code) || other.code == code)&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.heightM, heightM) || other.heightM == heightM)&&(identical(other.diameterM, diameterM) || other.diameterM == diameterM)&&(identical(other.masterId, masterId) || other.masterId == masterId)&&(identical(other.status, status) || other.status == status)&&(identical(other.note, note) || other.note == note)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,code,lat,lng,heightM,diameterM,masterId,status,note,createdBy,createdAt,updatedAt);

@override
String toString() {
  return 'Manhole(id: $id, code: $code, lat: $lat, lng: $lng, heightM: $heightM, diameterM: $diameterM, masterId: $masterId, status: $status, note: $note, createdBy: $createdBy, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$ManholeCopyWith<$Res> implements $ManholeCopyWith<$Res> {
  factory _$ManholeCopyWith(_Manhole value, $Res Function(_Manhole) _then) = __$ManholeCopyWithImpl;
@override @useResult
$Res call({
 String id, String code,@JsonKey(fromJson: _toDouble) double lat,@JsonKey(fromJson: _toDouble) double lng,@JsonKey(name: 'height_m', fromJson: _toNullableDouble) double? heightM,@JsonKey(name: 'diameter_m', fromJson: _toNullableDouble) double? diameterM,@JsonKey(name: 'master_id') String? masterId, WorkStatus status, String? note,@JsonKey(name: 'created_by') String? createdBy,@JsonKey(name: 'created_at') DateTime? createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt
});




}
/// @nodoc
class __$ManholeCopyWithImpl<$Res>
    implements _$ManholeCopyWith<$Res> {
  __$ManholeCopyWithImpl(this._self, this._then);

  final _Manhole _self;
  final $Res Function(_Manhole) _then;

/// Create a copy of Manhole
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? code = null,Object? lat = null,Object? lng = null,Object? heightM = freezed,Object? diameterM = freezed,Object? masterId = freezed,Object? status = null,Object? note = freezed,Object? createdBy = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_Manhole(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,lat: null == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double,lng: null == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double,heightM: freezed == heightM ? _self.heightM : heightM // ignore: cast_nullable_to_non_nullable
as double?,diameterM: freezed == diameterM ? _self.diameterM : diameterM // ignore: cast_nullable_to_non_nullable
as double?,masterId: freezed == masterId ? _self.masterId : masterId // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as WorkStatus,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,createdBy: freezed == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
