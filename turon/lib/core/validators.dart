import 'auth_utils.dart';

/// Pure validation functions for Manhole, Pipe, and Admin forms (LLD 1.2, 2.2, 4.7, Step 4).
class FormValidators {
  FormValidators._();

  static const List<int> standardPipeDiameters = [
    110,
    160,
    200,
    250,
    315,
    400,
    500,
  ];

  /// Parses an optional decimal string (accepting both `,` and `.` as separator).
  /// Empty or whitespace-only string returns `null` (never `0` or `""`).
  /// Rounds to at most 2 decimal places.
  static double? parseOptionalDecimal(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final normalized = trimmed.replaceAll(',', '.');
    final parsed = double.tryParse(normalized);
    if (parsed == null) return null;
    return (parsed * 100.0).roundToDouble() / 100.0;
  }

  static bool _hasAtMostTwoDecimals(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    final parts = normalized.split('.');
    if (parts.length > 2) return false;
    if (parts.length == 2 && parts[1].length > 2) return false;
    return true;
  }

  /// Validates code (`manholes.code` / `pipes.code`):
  /// If [allowEmpty] is true (e.g. on create where DB trigger auto-generates `K-1` / `Q-1`),
  /// empty is allowed; otherwise 1..32 chars.
  static String? validateCode(String? value, {bool allowEmpty = false}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return allowEmpty ? null : 'Kodni kiriting';
    }
    if (trimmed.length > 32) {
      return 'Kod 1..32 belgi bo\'lishi kerak';
    }
    return null;
  }

  /// Validates optional manhole height (m): empty allowed (→ null),
  /// accepts `,` and `.`, max 2 decimals, only rule: `> 0` (no upper limit).
  /// Optional Baltic-system elevation in metres (e.g. 85.73).
  static String? validateElevation(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final v = parseOptionalDecimal(value);
    if (v == null) return 'Raqam kiriting, masalan 85.73';
    if (v < -500 || v > 9000) return 'Otmetka -500 … 9000 m oralig\'ida bo\'lsin';
    return null;
  }

  static String? validateManholeHeight(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final parsed = double.tryParse(trimmed.replaceAll(',', '.'));
    if (parsed == null) {
      return 'Raqam kiriting';
    }
    if (!_hasAtMostTwoDecimals(trimmed)) {
      return 'Ko\'pi bilan 2 ta kasr xonasi bo\'lishi kerak';
    }
    if (parsed <= 0) {
      return 'Balandlik 0 dan katta bo\'lishi kerak';
    }
    return null;
  }

  /// Validates optional manhole diameter (m): empty allowed (→ null),
  /// accepts `,` and `.`, max 2 decimals, only rule: `> 0` (no upper limit).
  static String? validateManholeDiameterM(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final parsed = double.tryParse(trimmed.replaceAll(',', '.'));
    if (parsed == null) {
      return 'Raqam kiriting';
    }
    if (!_hasAtMostTwoDecimals(trimmed)) {
      return 'Ko\'pi bilan 2 ta kasr xonasi bo\'lishi kerak';
    }
    if (parsed <= 0) {
      return 'Diametr 0 dan katta bo\'lishi kerak';
    }
    return null;
  }

  /// Validates custom pipe diameter (mm) when "Boshqa" is selected:
  /// integer 50..2000 (LLD 1.2 & 4.7).
  static String? validatePipeCustomDiameter(
    String? value, {
    required bool isCustomSelected,
  }) {
    final trimmed = value?.trim() ?? '';
    if (!isCustomSelected) return null;
    if (trimmed.isEmpty) {
      return 'Diametrni kiriting (50..2000 mm)';
    }
    final parsed = int.tryParse(trimmed);
    if (parsed == null) {
      return 'Butun son kiriting';
    }
    if (parsed < 50 || parsed > 2000) {
      return 'Diametr 50..2000 mm oralig\'ida bo\'lishi kerak';
    }
    return null;
  }

  /// Validates manual pipe length (m) when manual override is enabled:
  /// accepts `,` and `.`, max 2 decimals, > 0 and <= 10000.
  static String? validatePipeManualLength(
    String? value, {
    required bool isManualEnabled,
  }) {
    if (!isManualEnabled) return null;
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Qo\'lda uzunlikni kiriting';
    }
    final parsed = double.tryParse(trimmed.replaceAll(',', '.'));
    if (parsed == null) {
      return 'Raqam kiriting';
    }
    if (!_hasAtMostTwoDecimals(trimmed)) {
      return 'Ko\'pi bilan 2 ta kasr xonasi bo\'lishi kerak';
    }
    if (parsed <= 0 || parsed > 10000) {
      return 'Uzunlik 0 dan katta va 10000 m gacha bo\'lishi kerak';
    }
    return null;
  }

  /// Validates optional note: max 500 chars.
  static String? validateNote(String? value) {
    if (value == null || value.isEmpty) return null;
    if (value.length > 500) {
      return 'Izoh 500 belgidan oshmasligi kerak';
    }
    return null;
  }

  /// Validates full name for admin user/master forms.
  static String? validateFullName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Ism-sharifni kiriting';
    }
    if (trimmed.length < 2) {
      return 'Ism-sharif kamida 2 ta belgidan iborat bo\'lishi kerak';
    }
    if (trimmed.length > 100) {
      return 'Ism-sharif 100 belgidan oshmasligi kerak';
    }
    return null;
  }

  /// Validates required Uzbek phone (9 digits or 998XXXXXXXXX).
  static String? validateRequiredPhone(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Telefon raqamini kiriting';
    }
    if (normalizePhone(trimmed) == null) {
      return 'Telefon raqami to\'liq emas (9 ta raqam)';
    }
    return null;
  }

  /// Validates optional Uzbek phone (empty or bare +998 prefix -> null, else valid 9 digits).
  static String? validateOptionalPhone(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty || trimmed == '+998' || trimmed == '998') return null;
    if (normalizePhone(trimmed) == null) {
      return 'Telefon raqami to\'liq emas (9 ta raqam)';
    }
    return null;
  }

  /// Validates 5-digit PIN.
  static String? validatePin(String? value) {
    if (!isValidPin(value ?? '')) {
      return '5 xonali PIN kiriting';
    }
    return null;
  }
}

