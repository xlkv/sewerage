// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pipe.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Pipe {

 String get id; String get code;@JsonKey(name: 'from_manhole_id') String get fromManholeId;@JsonKey(name: 'to_manhole_id') String get toManholeId;@JsonKey(name: 'diameter_mm') int get diameterMm;@JsonKey(name: 'length_auto_m', fromJson: _toDouble) double get lengthAutoM;@JsonKey(name: 'length_manual_m', fromJson: _toNullableDouble) double? get lengthManualM; WorkStatus get status;@JsonKey(fromJson: _pathFromJson, toJson: _pathToJson) List<List<double>> get path; String? get note;@JsonKey(name: 'created_by') String? get createdBy;@JsonKey(name: 'created_at') DateTime? get createdAt;@JsonKey(name: 'updated_at') DateTime? get updatedAt;
/// Create a copy of Pipe
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PipeCopyWith<Pipe> get copyWith => _$PipeCopyWithImpl<Pipe>(this as Pipe, _$identity);

  /// Serializes this Pipe to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Pipe&&(identical(other.id, id) || other.id == id)&&(identical(other.code, code) || other.code == code)&&(identical(other.fromManholeId, fromManholeId) || other.fromManholeId == fromManholeId)&&(identical(other.toManholeId, toManholeId) || other.toManholeId == toManholeId)&&(identical(other.diameterMm, diameterMm) || other.diameterMm == diameterMm)&&(identical(other.lengthAutoM, lengthAutoM) || other.lengthAutoM == lengthAutoM)&&(identical(other.lengthManualM, lengthManualM) || other.lengthManualM == lengthManualM)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.path, path)&&(identical(other.note, note) || other.note == note)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,code,fromManholeId,toManholeId,diameterMm,lengthAutoM,lengthManualM,status,const DeepCollectionEquality().hash(path),note,createdBy,createdAt,updatedAt);

@override
String toString() {
  return 'Pipe(id: $id, code: $code, fromManholeId: $fromManholeId, toManholeId: $toManholeId, diameterMm: $diameterMm, lengthAutoM: $lengthAutoM, lengthManualM: $lengthManualM, status: $status, path: $path, note: $note, createdBy: $createdBy, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $PipeCopyWith<$Res>  {
  factory $PipeCopyWith(Pipe value, $Res Function(Pipe) _then) = _$PipeCopyWithImpl;
@useResult
$Res call({
 String id, String code,@JsonKey(name: 'from_manhole_id') String fromManholeId,@JsonKey(name: 'to_manhole_id') String toManholeId,@JsonKey(name: 'diameter_mm') int diameterMm,@JsonKey(name: 'length_auto_m', fromJson: _toDouble) double lengthAutoM,@JsonKey(name: 'length_manual_m', fromJson: _toNullableDouble) double? lengthManualM, WorkStatus status,@JsonKey(fromJson: _pathFromJson, toJson: _pathToJson) List<List<double>> path, String? note,@JsonKey(name: 'created_by') String? createdBy,@JsonKey(name: 'created_at') DateTime? createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt
});




}
/// @nodoc
class _$PipeCopyWithImpl<$Res>
    implements $PipeCopyWith<$Res> {
  _$PipeCopyWithImpl(this._self, this._then);

  final Pipe _self;
  final $Res Function(Pipe) _then;

/// Create a copy of Pipe
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? code = null,Object? fromManholeId = null,Object? toManholeId = null,Object? diameterMm = null,Object? lengthAutoM = null,Object? lengthManualM = freezed,Object? status = null,Object? path = null,Object? note = freezed,Object? createdBy = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,fromManholeId: null == fromManholeId ? _self.fromManholeId : fromManholeId // ignore: cast_nullable_to_non_nullable
as String,toManholeId: null == toManholeId ? _self.toManholeId : toManholeId // ignore: cast_nullable_to_non_nullable
as String,diameterMm: null == diameterMm ? _self.diameterMm : diameterMm // ignore: cast_nullable_to_non_nullable
as int,lengthAutoM: null == lengthAutoM ? _self.lengthAutoM : lengthAutoM // ignore: cast_nullable_to_non_nullable
as double,lengthManualM: freezed == lengthManualM ? _self.lengthManualM : lengthManualM // ignore: cast_nullable_to_non_nullable
as double?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as WorkStatus,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as List<List<double>>,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,createdBy: freezed == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Pipe].
extension PipePatterns on Pipe {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Pipe value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Pipe() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Pipe value)  $default,){
final _that = this;
switch (_that) {
case _Pipe():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Pipe value)?  $default,){
final _that = this;
switch (_that) {
case _Pipe() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String code, @JsonKey(name: 'from_manhole_id')  String fromManholeId, @JsonKey(name: 'to_manhole_id')  String toManholeId, @JsonKey(name: 'diameter_mm')  int diameterMm, @JsonKey(name: 'length_auto_m', fromJson: _toDouble)  double lengthAutoM, @JsonKey(name: 'length_manual_m', fromJson: _toNullableDouble)  double? lengthManualM,  WorkStatus status, @JsonKey(fromJson: _pathFromJson, toJson: _pathToJson)  List<List<double>> path,  String? note, @JsonKey(name: 'created_by')  String? createdBy, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Pipe() when $default != null:
return $default(_that.id,_that.code,_that.fromManholeId,_that.toManholeId,_that.diameterMm,_that.lengthAutoM,_that.lengthManualM,_that.status,_that.path,_that.note,_that.createdBy,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String code, @JsonKey(name: 'from_manhole_id')  String fromManholeId, @JsonKey(name: 'to_manhole_id')  String toManholeId, @JsonKey(name: 'diameter_mm')  int diameterMm, @JsonKey(name: 'length_auto_m', fromJson: _toDouble)  double lengthAutoM, @JsonKey(name: 'length_manual_m', fromJson: _toNullableDouble)  double? lengthManualM,  WorkStatus status, @JsonKey(fromJson: _pathFromJson, toJson: _pathToJson)  List<List<double>> path,  String? note, @JsonKey(name: 'created_by')  String? createdBy, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Pipe():
return $default(_that.id,_that.code,_that.fromManholeId,_that.toManholeId,_that.diameterMm,_that.lengthAutoM,_that.lengthManualM,_that.status,_that.path,_that.note,_that.createdBy,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String code, @JsonKey(name: 'from_manhole_id')  String fromManholeId, @JsonKey(name: 'to_manhole_id')  String toManholeId, @JsonKey(name: 'diameter_mm')  int diameterMm, @JsonKey(name: 'length_auto_m', fromJson: _toDouble)  double lengthAutoM, @JsonKey(name: 'length_manual_m', fromJson: _toNullableDouble)  double? lengthManualM,  WorkStatus status, @JsonKey(fromJson: _pathFromJson, toJson: _pathToJson)  List<List<double>> path,  String? note, @JsonKey(name: 'created_by')  String? createdBy, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Pipe() when $default != null:
return $default(_that.id,_that.code,_that.fromManholeId,_that.toManholeId,_that.diameterMm,_that.lengthAutoM,_that.lengthManualM,_that.status,_that.path,_that.note,_that.createdBy,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _Pipe extends Pipe {
  const _Pipe({required this.id, required this.code, @JsonKey(name: 'from_manhole_id') required this.fromManholeId, @JsonKey(name: 'to_manhole_id') required this.toManholeId, @JsonKey(name: 'diameter_mm') required this.diameterMm, @JsonKey(name: 'length_auto_m', fromJson: _toDouble) this.lengthAutoM = 0, @JsonKey(name: 'length_manual_m', fromJson: _toNullableDouble) this.lengthManualM, this.status = WorkStatus.planned, @JsonKey(fromJson: _pathFromJson, toJson: _pathToJson) final  List<List<double>> path = const [], this.note, @JsonKey(name: 'created_by') this.createdBy, @JsonKey(name: 'created_at') this.createdAt, @JsonKey(name: 'updated_at') this.updatedAt}): _path = path,super._();
  factory _Pipe.fromJson(Map<String, dynamic> json) => _$PipeFromJson(json);

@override final  String id;
@override final  String code;
@override@JsonKey(name: 'from_manhole_id') final  String fromManholeId;
@override@JsonKey(name: 'to_manhole_id') final  String toManholeId;
@override@JsonKey(name: 'diameter_mm') final  int diameterMm;
@override@JsonKey(name: 'length_auto_m', fromJson: _toDouble) final  double lengthAutoM;
@override@JsonKey(name: 'length_manual_m', fromJson: _toNullableDouble) final  double? lengthManualM;
@override@JsonKey() final  WorkStatus status;
 final  List<List<double>> _path;
@override@JsonKey(fromJson: _pathFromJson, toJson: _pathToJson) List<List<double>> get path {
  if (_path is EqualUnmodifiableListView) return _path;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_path);
}

@override final  String? note;
@override@JsonKey(name: 'created_by') final  String? createdBy;
@override@JsonKey(name: 'created_at') final  DateTime? createdAt;
@override@JsonKey(name: 'updated_at') final  DateTime? updatedAt;

/// Create a copy of Pipe
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PipeCopyWith<_Pipe> get copyWith => __$PipeCopyWithImpl<_Pipe>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PipeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Pipe&&(identical(other.id, id) || other.id == id)&&(identical(other.code, code) || other.code == code)&&(identical(other.fromManholeId, fromManholeId) || other.fromManholeId == fromManholeId)&&(identical(other.toManholeId, toManholeId) || other.toManholeId == toManholeId)&&(identical(other.diameterMm, diameterMm) || other.diameterMm == diameterMm)&&(identical(other.lengthAutoM, lengthAutoM) || other.lengthAutoM == lengthAutoM)&&(identical(other.lengthManualM, lengthManualM) || other.lengthManualM == lengthManualM)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._path, _path)&&(identical(other.note, note) || other.note == note)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,code,fromManholeId,toManholeId,diameterMm,lengthAutoM,lengthManualM,status,const DeepCollectionEquality().hash(_path),note,createdBy,createdAt,updatedAt);

@override
String toString() {
  return 'Pipe(id: $id, code: $code, fromManholeId: $fromManholeId, toManholeId: $toManholeId, diameterMm: $diameterMm, lengthAutoM: $lengthAutoM, lengthManualM: $lengthManualM, status: $status, path: $path, note: $note, createdBy: $createdBy, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$PipeCopyWith<$Res> implements $PipeCopyWith<$Res> {
  factory _$PipeCopyWith(_Pipe value, $Res Function(_Pipe) _then) = __$PipeCopyWithImpl;
@override @useResult
$Res call({
 String id, String code,@JsonKey(name: 'from_manhole_id') String fromManholeId,@JsonKey(name: 'to_manhole_id') String toManholeId,@JsonKey(name: 'diameter_mm') int diameterMm,@JsonKey(name: 'length_auto_m', fromJson: _toDouble) double lengthAutoM,@JsonKey(name: 'length_manual_m', fromJson: _toNullableDouble) double? lengthManualM, WorkStatus status,@JsonKey(fromJson: _pathFromJson, toJson: _pathToJson) List<List<double>> path, String? note,@JsonKey(name: 'created_by') String? createdBy,@JsonKey(name: 'created_at') DateTime? createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt
});




}
/// @nodoc
class __$PipeCopyWithImpl<$Res>
    implements _$PipeCopyWith<$Res> {
  __$PipeCopyWithImpl(this._self, this._then);

  final _Pipe _self;
  final $Res Function(_Pipe) _then;

/// Create a copy of Pipe
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? code = null,Object? fromManholeId = null,Object? toManholeId = null,Object? diameterMm = null,Object? lengthAutoM = null,Object? lengthManualM = freezed,Object? status = null,Object? path = null,Object? note = freezed,Object? createdBy = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_Pipe(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,fromManholeId: null == fromManholeId ? _self.fromManholeId : fromManholeId // ignore: cast_nullable_to_non_nullable
as String,toManholeId: null == toManholeId ? _self.toManholeId : toManholeId // ignore: cast_nullable_to_non_nullable
as String,diameterMm: null == diameterMm ? _self.diameterMm : diameterMm // ignore: cast_nullable_to_non_nullable
as int,lengthAutoM: null == lengthAutoM ? _self.lengthAutoM : lengthAutoM // ignore: cast_nullable_to_non_nullable
as double,lengthManualM: freezed == lengthManualM ? _self.lengthManualM : lengthManualM // ignore: cast_nullable_to_non_nullable
as double?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as WorkStatus,path: null == path ? _self._path : path // ignore: cast_nullable_to_non_nullable
as List<List<double>>,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,createdBy: freezed == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
