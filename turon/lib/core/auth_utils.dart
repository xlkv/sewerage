final RegExp _phone12Regex = RegExp(r'^998\d{9}$');
final RegExp _phone9Regex = RegExp(r'^\d{9}$');
final RegExp _pinRegex = RegExp(r'^\d{5}$');

/// Uzbek operator codes change over time (20, 33, 70, 77, ...), so any
/// 2-digit code that does not start with 0 is accepted.
bool isValidUzbekCode(String code) => RegExp(r'^[1-9]\d$').hasMatch(code);

/// Returns true if the first 2 digits of a local phone (or digits after 998 in a 12-digit phone)
/// match a valid Uzbek operator code.
bool isValidOperatorCode(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 12 && digits.startsWith('998')) {
    return isValidUzbekCode(digits.substring(3, 5));
  }
  if (digits.length >= 2) {
    return isValidUzbekCode(digits.substring(0, 2));
  }
  return false;
}

/// Formats up to 9 local digits into live mask `+998 (90) 123-45-67`.
String formatUzbekPhoneMask(String rawLocalDigits) {
  var digits = rawLocalDigits.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 12 && digits.startsWith('998')) {
    digits = digits.substring(3);
  }
  if (digits.length > 9) {
    digits = digits.substring(0, 9);
  }

  if (digits.isEmpty) {
    return '+998';
  }
  if (digits.length == 1) {
    return '+998 ($digits';
  }
  if (digits.length == 2) {
    return '+998 ($digits)';
  }
  final op = digits.substring(0, 2);
  if (digits.length <= 5) {
    return '+998 ($op) ${digits.substring(2)}';
  }
  final part1 = digits.substring(2, 5);
  if (digits.length <= 7) {
    return '+998 ($op) $part1-${digits.substring(5)}';
  }
  final part2 = digits.substring(5, 7);
  final part3 = digits.substring(7);
  return '+998 ($op) $part1-$part2-$part3';
}

/// Normalizes a phone string (e.g. "+998 (90) 123-45-67" or "90 123 45 67")
/// to "998901234567". Returns null if invalid length or invalid Uzbek operator code.
String? normalizePhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  String? local9;
  if (_phone12Regex.hasMatch(digits)) {
    local9 = digits.substring(3);
  } else if (_phone9Regex.hasMatch(digits)) {
    local9 = digits;
  }
  if (local9 == null) return null;
  if (!isValidUzbekCode(local9.substring(0, 2))) {
    return null;
  }
  return '998$local9';
}

/// Converts a normalized phone ("998901234567") to its pseudo-email.
String pseudoEmail(String phone) => '$phone@users.turon.app';

/// Derives the Supabase password from a 5-digit PIN.
String derivePassword(String pin) => '$pin#Turon';

/// Validates that PIN consists of exactly 5 digits.
bool isValidPin(String pin) => _pinRegex.hasMatch(pin.trim());

