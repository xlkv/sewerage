import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models/work_status.dart';

class StatusChip extends StatelessWidget {
  final WorkStatus status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forStatus(status);
    return Chip(
      label: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
      backgroundColor: color.withValues(alpha: 0.14),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      visualDensity: VisualDensity.compact,
    );
  }
}
