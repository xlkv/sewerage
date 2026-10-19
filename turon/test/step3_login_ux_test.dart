import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:turon/core/auth_utils.dart';
import 'package:turon/data/models/profile.dart';
import 'package:turon/data/repositories/auth_repo.dart';
import 'package:turon/features/auth/login_screen.dart';
import 'package:turon/features/profile/profile_screen.dart';
import 'package:turon/shared/widgets/numeric_keypad.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  Future<void> tapDigits(WidgetTester tester, String digits) async {
    for (final ch in digits.split('')) {
      await tester.tap(find.byKey(ValueKey('keypad_$ch')));
      await tester.pump();
    }
  }

  group('Task A — Login UX & NumericKeypad widget tests', () {
    test('formatUzbekPhoneMask and isValidOperatorCode cover all Uzbek codes', () {
      const expectedCodes = [
        '33',
        '50',
        '55',
        '77',
        '88',
        '90',
        '91',
        '93',
        '94',
        '95',
        '97',
        '98',
        '99',
        '20',
      ];
      for (final code in expectedCodes) {
        expect(isValidOperatorCode(code), isTrue, reason: 'Code $code');
        expect(isValidOperatorCode('${code}1234567'), isTrue);
        expect(normalizePhone('${code}1234567'), '998${code}1234567');
      }

      for (final bad in ['00', '01', '05', '09', '1', '']) {
        expect(isValidOperatorCode(bad), isFalse, reason: 'Bad code $bad');
        expect(normalizePhone('${bad}1234567'), isNull);
      }

      expect(formatUzbekPhoneMask(''), '+998');
      expect(formatUzbekPhoneMask('9'), '+998 (9');
      expect(formatUzbekPhoneMask('90'), '+998 (90)');
      expect(formatUzbekPhoneMask('90123'), '+998 (90) 123');
      expect(formatUzbekPhoneMask('9012345'), '+998 (90) 123-45');
      expect(formatUzbekPhoneMask('901234567'), '+998 (90) 123-45-67');
    });

    testWidgets(
      'Phone step: live mask formatting, keypad input, backspace, and long-press clear',
      (tester) async {
        final mockAuth = _MockAuthRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [authRepoProvider.overrideWithValue(mockAuth)],
            child: const MaterialApp(home: LoginScreen()),
          ),
        );

        // System keyboard must never be used (no EditableText / TextField).
        expect(find.byType(EditableText), findsNothing);

        // Initially shows +998 and disabled "Davom etish"
        expect(find.text('+998'), findsOneWidget);
        final continueBtnFinder = find.byKey(const ValueKey('continue_button'));
        expect(
          tester.widget<FilledButton>(continueBtnFinder).onPressed,
          isNull,
        );

        // Type 901234567 via custom keypad
        await tapDigits(tester, '90');
        expect(find.text('+998 (90)'), findsOneWidget);

        await tapDigits(tester, '123');
        expect(find.text('+998 (90) 123'), findsOneWidget);

        await tapDigits(tester, '4567');
        expect(find.text('+998 (90) 123-45-67'), findsOneWidget);

        // "Davom etish" is now enabled
        expect(
          tester.widget<FilledButton>(continueBtnFinder).onPressed,
          isNotNull,
        );

        // Single backspace removes last digit -> 8 digits -> button disabled
        await tester.tap(find.byKey(const ValueKey('keypad_backspace')));
        await tester.pump();
        expect(find.text('+998 (90) 123-45-6'), findsOneWidget);
        expect(
          tester.widget<FilledButton>(continueBtnFinder).onPressed,
          isNull,
        );

        // Long-press backspace clears all digits back to +998
        await tester.longPress(find.byKey(const ValueKey('keypad_backspace')));
        await tester.pump();
        expect(find.text('+998'), findsOneWidget);
      },
    );

    testWidgets(
      'Operator validation shows inline error for invalid code and keeps Davom etish disabled',
      (tester) async {
        final mockAuth = _MockAuthRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [authRepoProvider.overrideWithValue(mockAuth)],
            child: const MaterialApp(home: LoginScreen()),
          ),
        );

        // Enter invalid operator code "11" + 7 digits
        await tapDigits(tester, '01');
        expect(
          find.byKey(const ValueKey('operator_error_text')),
          findsOneWidget,
        );
        expect(find.text('Operator kodi noto\'g\'ri'), findsOneWidget);

        await tapDigits(tester, '1234567');
        expect(find.text('+998 (01) 123-45-67'), findsOneWidget);
        expect(find.text('Operator kodi noto\'g\'ri'), findsOneWidget);

        // Even with 9 digits, "Davom etish" remains disabled because operator code is invalid
        final continueBtnFinder = find.byKey(const ValueKey('continue_button'));
        expect(
          tester.widget<FilledButton>(continueBtnFinder).onPressed,
          isNull,
        );

        // Long-press clear and enter valid operator 93
        await tester.longPress(find.byKey(const ValueKey('keypad_backspace')));
        await tester.pump();
        expect(find.byKey(const ValueKey('operator_error_text')), findsNothing);

        await tapDigits(tester, '931234567');
        expect(find.byKey(const ValueKey('operator_error_text')), findsNothing);
        expect(
          tester.widget<FilledButton>(continueBtnFinder).onPressed,
          isNotNull,
        );
      },
    );

    testWidgets(
      'PIN step: active box highlight, filled dots, auto-submit on 5th digit, and wrong PIN shake/clear',
      (tester) async {
        final mockAuth = _MockAuthRepository();
        final signInCompleter = Completer<Profile>();

        when(
          () => mockAuth.signIn(
            phone: any(named: 'phone'),
            pin: any(named: 'pin'),
          ),
        ).thenAnswer((_) => signInCompleter.future);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [authRepoProvider.overrideWithValue(mockAuth)],
            child: const MaterialApp(home: LoginScreen()),
          ),
        );

        // Complete step 1
        await tapDigits(tester, '901234567');
        await tester.tap(find.byKey(const ValueKey('continue_button')));
        await tester.pump();
        // Let the step-switch transition finish.
        await tester.pump(const Duration(milliseconds: 400));

        // Step 2 shows formatted phone + "O'zgartirish" link + 5 PIN boxes
        expect(find.text('+998 (90) 123-45-67'), findsOneWidget);
        expect(find.text('O\'zgartirish'), findsOneWidget);
        expect(find.byType(PinBox), findsNWidgets(5));

        // Initially box 0 is active and 0 boxes are filled
        expect(
          tester.widget<PinBox>(find.byKey(const ValueKey('pin_box_0'))).isActive,
          isTrue,
        );
        expect(find.text('●'), findsNothing);

        // Enter 4 digits: 4 dots shown, box 4 is active, signIn not called yet
        await tapDigits(tester, '1234');
        expect(find.text('●'), findsNWidgets(4));
        expect(
          tester.widget<PinBox>(find.byKey(const ValueKey('pin_box_4'))).isActive,
          isTrue,
        );
        verifyNever(
          () => mockAuth.signIn(
            phone: any(named: 'phone'),
            pin: any(named: 'pin'),
          ),
        );

        // Enter 5th digit -> auto-submits immediately and shows progress indicator
        await tapDigits(tester, '5');
        verify(
          () => mockAuth.signIn(phone: '998901234567', pin: '12345'),
        ).called(1);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Fail with wrong PIN -> shakes, clears boxes, shows "Telefon yoki parol noto'g'ri"
        signInCompleter.completeError(
          const AuthException(
            'Invalid login credentials',
            code: 'invalid_credentials',
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 450));

        expect(find.text('Telefon yoki parol noto\'g\'ri'), findsOneWidget);
        expect(find.text('●'), findsNothing);
        expect(
          tester.widget<PinBox>(find.byKey(const ValueKey('pin_box_0'))).isFilled,
          isFalse,
        );

        // Tap "O'zgartirish" -> returns to phone step with phone preserved
        await tester.tap(find.byKey(const ValueKey('change_phone_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byKey(const ValueKey('continue_button')), findsOneWidget);
        expect(find.text('+998 (90) 123-45-67'), findsOneWidget);
      },
    );

    testWidgets(
      'Tablet layout (width >= 600) centers login card with max-width 420',
      (tester) async {
        tester.view.physicalSize = const Size(900, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockAuth = _MockAuthRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [authRepoProvider.overrideWithValue(mockAuth)],
            child: const MaterialApp(home: LoginScreen()),
          ),
        );

        final constrained = tester.widget<ConstrainedBox>(
          find.byKey(const ValueKey('login_card_constraints')),
        );
        expect(constrained.constraints.maxWidth, 420);
        expect(find.byKey(const ValueKey('login_tablet_card')), findsOneWidget);
      },
    );

    testWidgets(
      'Profile PIN o\'zgartirish reuses PinBoxes + NumericKeypad (old -> new -> repeat)',
      (tester) async {
        final mockAuth = _MockAuthRepository();
        when(
          () => mockAuth.changePin(
            oldPin: any(named: 'oldPin'),
            newPin: any(named: 'newPin'),
          ),
        ).thenAnswer((_) async {});

        const testProfile = Profile(
          id: 'u-1',
          fullName: 'Test Foydalanuvchi',
          phone: '998901234567',
          role: AppRole.user,
          isActive: true,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepoProvider.overrideWithValue(mockAuth),
              currentProfileProvider.overrideWith((_) async => testProfile),
            ],
            child: const MaterialApp(home: ProfileScreen()),
          ),
        );
        await tester.pump();

        expect(find.byType(EditableText), findsNothing);
        expect(find.byType(PinBoxes), findsOneWidget);
        expect(find.byType(NumericKeypad), findsOneWidget);
        expect(
          find.text('1/3 • Joriy PIN kodni kiriting'),
          findsOneWidget,
        );

        // Step 1: enter old PIN (11111)
        await tapDigits(tester, '11111');
        expect(
          find.text('2/3 • Yangi PIN kodni kiriting'),
          findsOneWidget,
        );

        // Step 2: enter new PIN (22222)
        await tapDigits(tester, '22222');
        expect(
          find.text('3/3 • Yangi PIN kodni qayta kiriting'),
          findsOneWidget,
        );

        // Step 3: enter mismatched repeat PIN (99999) -> error + clear repeat boxes
        await tapDigits(tester, '99999');
        await tester.pump(const Duration(milliseconds: 450));
        expect(find.text('PIN kodlar mos kelmadi'), findsOneWidget);
        expect(find.text('●'), findsNothing);

        // Re-enter matching repeat PIN (22222) -> auto-submits changePin
        await tapDigits(tester, '22222');
        await tester.pump();
        verify(
          () => mockAuth.changePin(oldPin: '11111', newPin: '22222'),
        ).called(1);
      },
    );
  });
}
