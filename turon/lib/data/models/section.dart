import 'package:freezed_annotation/freezed_annotation.dart';
import 'work_status.dart';

part 'section.freezed.dart';
part 'section.g.dart';

/// Uchastka: a named stretch of the network (pipes + manholes) with
/// attached drawings.
@freezed
abstract class Section with _$Section {
  const Section._();

  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Section({
    required String id,
    required String name,
    String? note,
    @Default(WorkStatus.planned) WorkStatus status,
    @JsonKey(name: 'start_date') DateTime? startDate,
    @JsonKey(name: 'end_date') DateTime? endDate,
    @JsonKey(name: 'created_by') String? createdBy,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _Section;

  factory Section.fromJson(Map<String, dynamic> json) =>
      _$SectionFromJson(json);
}

/// A PNG/JPEG/PDF attached to a section (stored in `section-files`).
@freezed
abstract class SectionFile with _$SectionFile {
  const SectionFile._();

  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory SectionFile({
    required String id,
    @JsonKey(name: 'section_id') required String sectionId,
    required String name,
    required String path,
    String? mime,
    @JsonKey(name: 'size_bytes') int? sizeBytes,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _SectionFile;

  factory SectionFile.fromJson(Map<String, dynamic> json) =>
      _$SectionFileFromJson(json);

  bool get isPdf =>
      mime == 'application/pdf' || name.toLowerCase().endsWith('.pdf');
}
