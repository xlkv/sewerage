import 'package:json_annotation/json_annotation.dart';

@JsonEnum(fieldRename: FieldRename.snake)
enum WorkStatus {
  @JsonValue('planned')
  planned,
  @JsonValue('in_progress')
  inProgress,
  @JsonValue('completed')
  completed;

  String get label => switch (this) {
    WorkStatus.planned => 'Rejalashtirilgan',
    WorkStatus.inProgress => 'Jarayonda',
    WorkStatus.completed => 'Tugallangan',
  };

  String toJsonValue() => switch (this) {
    WorkStatus.planned => 'planned',
    WorkStatus.inProgress => 'in_progress',
    WorkStatus.completed => 'completed',
  };

  static WorkStatus fromJsonValue(String value) => switch (value) {
    'planned' => WorkStatus.planned,
    'in_progress' => WorkStatus.inProgress,
    'completed' => WorkStatus.completed,
    _ => WorkStatus.planned,
  };
}
