import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_utils.dart';
import '../../core/errors.dart';
import '../../core/responsive.dart';
import '../../data/repositories/auth_repo.dart';
import '../../shared/widgets/numeric_keypad.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  int _step = 0; // 0 = Phone step, 1 = PIN step
  String _phoneDigits = '';
  String _pin = '';

  bool _isLoading = false;
  String? _pinErrorMessage;
  int _shakeTrigger = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
      SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    });
  }

  bool get _hasInvalidOperator =>
      _phoneDigits.length >= 2 && !isValidOperatorCode(_phoneDigits);

  bool get _isPhoneValid =>
      _phoneDigits.length == 9 && isValidOperatorCode(_phoneDigits);

  void _onPhoneDigit(String digit) {
    if (_phoneDigits.length >= 9) return;
    setState(() {
      _phoneDigits += digit;
    });
  }

  void _onPhoneBackspace() {
    if (_phoneDigits.isEmpty) return;
    setState(() {
      _phoneDigits = _phoneDigits.substring(0, _phoneDigits.length - 1);
    });
  }

  void _onPhoneClearAll() {
    if (_phoneDigits.isEmpty) return;
    setState(() {
      _phoneDigits = '';
    });
  }

  void _goToPinStep() {
    if (!_isPhoneValid) return;
    setState(() {
      _step = 1;
      _pin = '';
      _pinErrorMessage = null;
    });
  }

  void _backToPhoneStep() {
    if (_isLoading) return;
    setState(() {
      _step = 0;
      _pin = '';
      _pinErrorMessage = null;
    });
  }

  void _onPinDigit(String digit) {
    if (_isLoading || _pin.length >= 5) return;
    final nextPin = '$_pin$digit';
    setState(() {
      _pin = nextPin;
      _pinErrorMessage = null;
    });
    if (nextPin.length == 5) {
      _submitPin(nextPin);
    }
  }

  void _onPinBackspace() {
    if (_isLoading || _pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _pinErrorMessage = null;
    });
  }

  void _onPinClearAll() {
    if (_isLoading || _pin.isEmpty) return;
    setState(() {
      _pin = '';
      _pinErrorMessage = null;
    });
  }

  Future<void> _submitPin(String pin) async {
    setState(() {
      _isLoading = true;
      _pinErrorMessage = null;
    });

    try {
      await ref.read(authRepoProvider).signIn(
            phone: '998$_phoneDigits',
            pin: pin,
          );
      ref.invalidate(currentProfileProvider);
      if (mounted) {
        try {
          context.go('/');
        } catch (_) {
          // GoRouter may not be mounted in standalone widget tests.
        }
      }
    } catch (e) {
      if (mounted) {
        final mapped = mapErrorToMessage(e);
        setState(() {
          _pin = '';
          _shakeTrigger++;
          _pinErrorMessage =
              mapped == 'Xatolik yuz berdi. Qayta urinib ko\'ring'
              ? 'Telefon yoki parol noto\'g\'ri'
              : mapped;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildPhoneStep(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maskedText = formatUzbekPhoneMask(_phoneDigits);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const ValueKey('phone_input_display'),
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hasInvalidOperator
                  ? colorScheme.error
                  : colorScheme.primary,
              width: 1.8,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.phone_outlined,
                color: _hasInvalidOperator
                    ? colorScheme.error
                    : colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Text(
                        maskedText,
                        key: const ValueKey('phone_mask_text'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                      ),
                      if (_phoneDigits.isEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          '(90) 123-45-67',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.45,
                                ),
                                letterSpacing: 0.5,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_hasInvalidOperator) ...[
          const SizedBox(height: 6),
          Text(
            'Operator kodi noto\'g\'ri',
            key: const ValueKey('operator_error_text'),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
          ),
        ] else
          const SizedBox(height: 10),
        const SizedBox(height: 6),
        SizedBox(
          height: 48,
          child: FilledButton(
            key: const ValueKey('continue_button'),
            onPressed: _isPhoneValid ? _goToPinStep : null,
            child: const Text('Davom etish'),
          ),
        ),
        const SizedBox(height: 12),
        NumericKeypad(
          onDigitPressed: _onPhoneDigit,
          onBackspace: _onPhoneBackspace,
          onClearAll: _onPhoneClearAll,
        ),
      ],
    );
  }

  Widget _buildPinStep(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maskedPhone = formatUzbekPhoneMask(_phoneDigits);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                maskedPhone,
                key: const ValueKey('pin_step_phone'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              key: const ValueKey('change_phone_button'),
              onPressed: _isLoading ? null : _backToPhoneStep,
              child: const Text('O\'zgartirish'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        PinBoxes(
          pin: _pin,
          hasError: _pinErrorMessage != null,
          isActive: !_isLoading,
          shakeTrigger: _shakeTrigger,
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          const Center(
            child: SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          )
        else if (_pinErrorMessage != null)
          Text(
            _pinErrorMessage!,
            key: const ValueKey('pin_error_text'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.error,
              fontWeight: FontWeight.w500,
            ),
          )
        else
          Text(
            '5 xonali PIN kodni kiriting',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 12),
        NumericKeypad(
          enabled: !_isLoading,
          onDigitPressed: _onPinDigit,
          onBackspace: _onPinBackspace,
          onClearAll: _onPinClearAll,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tablet = isTablet(context);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: _AnimatedLogo()),
        const SizedBox(height: 12),
        Text(
          'Turon',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          'Kanalizatsiya tarmog\'i xaritasi',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0.08, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(
            key: ValueKey(_step),
            child: _step == 0
                ? _buildPhoneStep(context)
                : _buildPinStep(context),
          ),
        ),
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: ConstrainedBox(
              key: const ValueKey('login_card_constraints'),
              constraints: const BoxConstraints(maxWidth: 420),
              child: tablet
                  ? Card(
                      key: const ValueKey('login_tablet_card'),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: content,
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: content,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}


/// Brand tile whose water drop "fills up" from the bottom on first show.
class _AnimatedLogo extends StatelessWidget {
  const _AnimatedLogo();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        return Transform.scale(
          scale: 0.7 + 0.3 * Curves.easeOutBack.transform(t.clamp(0.0, 1.0)),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF14B8A6), AppColors.brand],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brand.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (rect) => LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: const [
                  Colors.white,
                  Colors.white,
                  Color(0x55FFFFFF),
                  Color(0x55FFFFFF),
                ],
                stops: [0, t, t, 1],
              ).createShader(rect),
              child: const Icon(
                Icons.water_drop_rounded,
                size: 40,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}
