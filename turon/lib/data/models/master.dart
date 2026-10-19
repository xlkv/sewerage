import 'package:freezed_annotation/freezed_annotation.dart';

part 'master.freezed.dart';
part 'master.g.dart';

@freezed
abstract class Master with _$Master {
  const Master._();

  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Master({
    required String id,
    @JsonKey(name: 'full_name') required String fullName,
    String? phone,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _Master;

  factory Master.fromJson(Map<String, dynamic> json) => _$MasterFromJson(json);
}
