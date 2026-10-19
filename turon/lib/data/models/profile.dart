import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile.freezed.dart';
part 'profile.g.dart';

@JsonEnum(fieldRename: FieldRename.snake)
enum AppRole {
  @JsonValue('admin')
  admin,
  @JsonValue('user')
  user;

  String get label => switch (this) {
    AppRole.admin => 'Admin',
    AppRole.user => 'Foydalanuvchi',
  };
}

@freezed
abstract class Profile with _$Profile {
  const Profile._();

  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Profile({
    required String id,
    @JsonKey(name: 'full_name') required String fullName,
    required String phone,
    @Default(AppRole.user) AppRole role,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _Profile;

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);

  bool get isAdmin => role == AppRole.admin && isActive;
}
