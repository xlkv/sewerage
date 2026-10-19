import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:turon/core/auth_utils.dart';
import 'package:turon/core/errors.dart';
import 'package:turon/data/models/manhole.dart';
import 'package:turon/data/models/master.dart';
import 'package:turon/data/models/pipe.dart';
import 'package:turon/data/models/profile.dart';
import 'package:turon/data/models/work_status.dart';

void main() {
  group('auth_utils', () {
    test('normalizePhone formats valid 12-digit and 9-digit phones', () {
      expect(normalizePhone('+998 90 123-45-67'), '998901234567');
      expect(normalizePhone('998901234567'), '998901234567');
      expect(normalizePhone('90 123 45 67'), '998901234567');
    });

    test('normalizePhone returns null for invalid phones', () {
      expect(normalizePhone(''), isNull);
      expect(normalizePhone('12345'), isNull);
      expect(normalizePhone('+7 900 123 45 67'), isNull);
      expect(normalizePhone('9989012345678'), isNull);
    });

    test('pseudoEmail returns expected domain format', () {
      expect(
        pseudoEmail('998901234567'),
        '998901234567@users.turon.app',
      );
    });

    test('derivePassword appends #Turon suffix to PIN', () {
      expect(derivePassword('12345'), '12345#Turon');
      expect(derivePassword('00000'), '00000#Turon');
    });

    test('isValidPin validates 5-digit PIN', () {
      expect(isValidPin('12345'), isTrue);
      expect(isValidPin('1234'), isFalse);
      expect(isValidPin('123456'), isFalse);
      expect(isValidPin('12a45'), isFalse);
    });
  });

  group('error mapping (LLD 4.9)', () {
    test('maps PostgrestException 23503 (foreign key restrict)', () {
      const err = PostgrestException(
        message: 'update or delete on table "manholes" violates foreign key',
        code: '23503',
      );
      expect(
        mapErrorToMessage(err),
        'Bog\'langan quvurlar bor — avval ularni o\'chiring',
      );
    });

    test('maps PostgrestException 23505 for code unique violation', () {
      const err = PostgrestException(
        message: 'duplicate key value violates unique constraint "manholes_code_key"',
        code: '23505',
      );
      expect(mapErrorToMessage(err), 'Bu raqam band');
    });

    test('maps PostgrestException 23505 for pipes_unique_pair', () {
      const err = PostgrestException(
        message: 'duplicate key value violates unique constraint "pipes_unique_pair"',
        code: '23505',
      );
      expect(
        mapErrorToMessage(err),
        'Bu kolodetslar allaqachon ulangan',
      );
    });

    test('maps PostgrestException 23514 (check constraint)', () {
      const err = PostgrestException(
        message: 'new row violates check constraint',
        code: '23514',
      );
      expect(
        mapErrorToMessage(err),
        'Kiritilgan qiymat ruxsat etilgan oraliqda emas',
      );
    });

    test('maps PostgrestException 42501 and 403 to permission error', () {
      const err = PostgrestException(
        message: 'permission denied for table manholes',
        code: '42501',
      );
      expect(
        mapErrorToMessage(err),
        'Sizda bu amal uchun ruxsat yo\'q',
      );

      const fnErr = FunctionException(status: 403, details: 'forbidden');
      expect(
        mapErrorToMessage(fnErr),
        'Sizda bu amal uchun ruxsat yo\'q',
      );
    });

    test('maps AuthException invalid_credentials', () {
      const err = AuthException(
        'Invalid login credentials',
        code: 'invalid_credentials',
      );
      expect(
        mapErrorToMessage(err),
        'Telefon yoki parol noto\'g\'ri',
      );
    });

    test('maps SocketException / network error', () {
      const err = SocketException('Failed host lookup');
      expect(
        mapErrorToMessage(err),
        'Internet aloqasi yo\'q. Qayta urinib ko\'ring',
      );
    });
  });

  group('models snake_case json', () {
    test('Pipe lengthM and isManual work as specified in LLD 4.3', () {
      final autoPipe = Pipe.fromJson({
        'id': 'p1',
        'code': 'Q-1',
        'from_manhole_id': 'm1',
        'to_manhole_id': 'm2',
        'diameter_mm': 200,
        'length_auto_m': '48.30',
        'length_manual_m': null,
        'status': 'in_progress',
      });
      expect(autoPipe.lengthM, 48.30);
      expect(autoPipe.isManual, isFalse);
      expect(autoPipe.status, WorkStatus.inProgress);

      final manualPipe = autoPipe.copyWith(lengthManualM: 50.0);
      expect(manualPipe.lengthM, 50.0);
      expect(manualPipe.isManual, isTrue);
    });

    test('Profile isAdmin and Manhole/Master snake_case parsing', () {
      final admin = Profile.fromJson({
        'id': 'u1',
        'full_name': 'Admin User',
        'phone': '998901234567',
        'role': 'admin',
        'is_active': true,
      });
      expect(admin.isAdmin, isTrue);

      final manhole = Manhole.fromJson({
        'id': 'm1',
        'code': 'K-1',
        'lat': 41.3111,
        'lng': 69.2797,
        'height_m': 2.5,
        'diameter_m': 1.0,
        'status': 'completed',
      });
      expect(manhole.heightM, 2.5);
      expect(manhole.status, WorkStatus.completed);

      final master = Master.fromJson({
        'id': 'ms1',
        'full_name': 'Usta Ali',
        'phone': '998901112233',
        'is_active': true,
      });
      expect(master.fullName, 'Usta Ali');
    });
  });
}
