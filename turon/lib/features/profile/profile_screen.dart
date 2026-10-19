import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_utils.dart';
import '../../core/errors.dart';
import '../../data/repositories/auth_repo.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/numeric_keypad.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _pinStep = 0; // 0 = old PIN, 1 = new PIN, 2 = repeat new PIN
  String _oldPin = '';
  String _newPin = '';
  String _repeatPin = '';

  bool _isSaving = false;
  String? _pinError;
  int _shakeTrigger = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
      SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    });
  }

  String get _currentPin => switch (_pinStep) {
    0 => _oldPin,
    1 => _newPin,
    _ => _repeatPin,
  };

  String get _stepTitle => switch (_pinStep) {
    0 => 'Joriy PIN kodni kiriting',
    1 => 'Yangi PIN kodni kiriting',
    _ => 'Yangi PIN kodni qayta kiriting',
  };

  void _setCurrentPin(String value) {
    switch (_pinStep) {
      case 0:
        _oldPin = value;
      case 1:
        _newPin = value;
      default:
        _repeatPin = value;
    }
  }

  void _onDigit(String digit) {
    if (_isSaving || _currentPin.length >= 5) return;
    final next = '$_currentPin$digit';
    setState(() {
      _setCurrentPin(next);
      _pinError = null;
    });

    if (next.length == 5) {
      if (_pinStep == 0) {
        setState(() {
          _pinStep = 1;
        });
      } else if (_pinStep == 1) {
        setState(() {
          _pinStep = 2;
        });
      } else {
        if (next != _newPin) {
          setState(() {
            _repeatPin = '';
            _shakeTrigger++;
            _pinError = 'PIN kodlar mos kelmadi';
          });
        } else {
          _submitChangePin(oldPin: _oldPin, newPin: _newPin);
        }
      }
    }
  }

  void _onBackspace() {
    if (_isSaving || _currentPin.isEmpty) return;
    setState(() {
      _setCurrentPin(_currentPin.substring(0, _currentPin.length - 1));
      _pinError = null;
    });
  }

  void _onClearAll() {
    if (_isSaving || _currentPin.isEmpty) return;
    setState(() {
      _setCurrentPin('');
      _pinError = null;
    });
  }

  void _resetPinFlow() {
    if (_isSaving) return;
    setState(() {
      _pinStep = 0;
      _oldPin = '';
      _newPin = '';
      _repeatPin = '';
      _pinError = null;
    });
  }

  Future<void> _submitChangePin({
    required String oldPin,
    required String newPin,
  }) async {
    setState(() {
      _isSaving = true;
      _pinError = null;
    });

    try {
      await ref.read(authRepoProvider).changePin(
            oldPin: oldPin,
            newPin: newPin,
          );
      if (mounted) {
        setState(() {
          _pinStep = 0;
          _oldPin = '';
          _newPin = '';
          _repeatPin = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN kod muvaffaqiyatli o\'zgartirildi')),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = mapErrorToMessage(e);
        setState(() {
          _pinStep = 0;
          _oldPin = '';
          _newPin = '';
          _repeatPin = '';
          _shakeTrigger++;
          _pinError = msg;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _onSignOut() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Tizimdan chiqish',
      message: 'Haqiqatan ham hisobingizdan chiqmoqchimisiz?',
      confirmLabel: 'Chiqish',
      isDestructive: true,
    );
    if (!confirmed) return;

    await ref.read(authRepoProvider).signOut();
    ref.invalidate(currentProfileProvider);
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  profileAsync.when(
                    data: (profile) {
                      if (profile == null) {
                        return const SizedBox.shrink();
                      }
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.fullName,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Telefon: ${formatUzbekPhoneMask(profile.phone)}',
                              ),
                              const SizedBox(height: 4),
                              Text('Rol: ${profile.role.label}'),
                            ],
                          ),
                        ),
                      );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (err, _) => Text(mapErrorToMessage(err)),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'PIN o\'zgartirish',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (_pinStep > 0)
                        TextButton(
                          key: const ValueKey('profile_pin_reset_button'),
                          onPressed: _isSaving ? null : _resetPinFlow,
                          child: const Text('Boshidan'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_pinStep + 1}/3 • $_stepTitle',
                    key: const ValueKey('profile_pin_step_label'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  PinBoxes(
                    pin: _currentPin,
                    hasError: _pinError != null,
                    isActive: !_isSaving,
                    shakeTrigger: _shakeTrigger,
                  ),
                  const SizedBox(height: 12),
                  if (_isSaving)
                    const Center(
                      child: SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  else if (_pinError != null)
                    Text(
                      _pinError!,
                      key: const ValueKey('profile_pin_error_text'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  const SizedBox(height: 12),
                  NumericKeypad(
                    enabled: !_isSaving,
                    onDigitPressed: _onDigit,
                    onBackspace: _onBackspace,
                    onClearAll: _onClearAll,
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _onSignOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Tizimdan chiqish'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
