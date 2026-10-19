import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, {this.code});

  @override
  String toString() => message;
}

String mapErrorToMessage(Object error) {
  if (error is AppException) {
    final code = (error.code ?? '').toLowerCase();
    if (code == 'phone_exists') {
      return 'Bu raqam allaqachon ro\'yxatda';
    }
    if (code == 'self_change') {
      return 'O\'zingizni o\'zgartira olmaysiz';
    }
    if (code == 'forbidden') {
      return 'Sizda bu amal uchun ruxsat yo\'q';
    }
    return error.message;
  }

  if (error is PostgrestException) {
    final code = error.code;
    final combined = '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
        .toLowerCase();

    if (code == '23503') {
      return 'Bog\'langan quvurlar bor — avval ularni o\'chiring';
    }
    if (code == '23505') {
      if (combined.contains('pipes_unique_pair')) {
        return 'Bu kolodetslar allaqachon ulangan';
      }
      return 'Bu raqam band';
    }
    if (code == '23514') {
      return 'Kiritilgan qiymat ruxsat etilgan oraliqda emas';
    }
    if (code == '42501' || code == '403') {
      return 'Sizda bu amal uchun ruxsat yo\'q';
    }
  }

  if (error is AuthException) {
    final code = (error.code ?? '').toLowerCase();
    final msg = error.message.toLowerCase();
    if (code == 'invalid_credentials' ||
        msg.contains('invalid login credentials') ||
        msg.contains('invalid_credentials')) {
      return 'Telefon yoki parol noto\'g\'ri';
    }
    if (error.statusCode == '403' || code == 'forbidden') {
      return 'Sizda bu amal uchun ruxsat yo\'q';
    }
    if (msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('clientexception')) {
      return 'Internet aloqasi yo\'q. Qayta urinib ko\'ring';
    }
  }

  if (error is FunctionException) {
    if (error.status == 403) {
      return 'Sizda bu amal uchun ruxsat yo\'q';
    }
    final detailsStr = '${error.details ?? ''} ${error.reasonPhrase ?? ''}'
        .toLowerCase();
    if (detailsStr.contains('phone_exists')) {
      return 'Bu raqam allaqachon ro\'yxatda';
    }
    if (detailsStr.contains('self_change')) {
      return 'O\'zingizni o\'zgartira olmaysiz';
    }
    if (detailsStr.contains('invalid_input')) {
      return 'Kiritilgan qiymat ruxsat etilgan oraliqda emas';
    }
    if (detailsStr.contains('forbidden')) {
      return 'Sizda bu amal uchun ruxsat yo\'q';
    }
  }

  if (error is SocketException) {
    return 'Internet aloqasi yo\'q. Qayta urinib ko\'ring';
  }

  final raw = error.toString().toLowerCase();
  if (raw.contains('socketexception') ||
      raw.contains('failed host lookup') ||
      raw.contains('network is unreachable') ||
      raw.contains('connection refused') ||
      raw.contains('clientexception')) {
    return 'Internet aloqasi yo\'q. Qayta urinib ko\'ring';
  }

  return 'Xatolik yuz berdi. Qayta urinib ko\'ring';
}
