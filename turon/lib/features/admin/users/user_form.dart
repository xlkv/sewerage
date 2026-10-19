import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth_utils.dart';
import '../../../core/errors.dart';
import '../../../core/validators.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/admin_users_repo.dart';
import '../../../data/repositories/auth_repo.dart';
import '../../../shared/widgets/numeric_keypad.dart';

/// Live input formatter that formats Uzbek phone digits into `+998 (90) 123-45-67`
/// and cleanly deletes digits on backspace even when the cursor is after mask characters.
class UzbekPhoneMaskFormatter extends TextInputFormatter {
  const UzbekPhoneMaskFormatter();

  static String extract9Digits(String text) {
    var digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('998')) {
      digits = digits.substring(3);
    }
    if (digits.length > 9) {
      digits = digits.substring(0, 9);
    }
    return digits;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldDigits = extract9Digits(oldValue.text);
    var digits = extract9Digits(newValue.text);

    // If backspace deleted a non-digit mask character (e.g. ')', '-', space),
    // remove the last digit so backspace never gets stuck on mask characters.
    if (newValue.text.length < oldValue.text.length &&
        digits == oldDigits &&
        digits.isNotEmpty) {
      digits = digits.substring(0, digits.length - 1);
    }

    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '+998',
        selection: TextSelection.collapsed(offset: 4),
      );
    }
    final formatted = formatUzbekPhoneMask(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

enum _UserFormKeypadTarget { none, phone, pin }

/// Bottom sheet / dialog form for creating a new user (`create`) or editing an existing user (`update`).
class UserForm extends ConsumerStatefulWidget {
  final Profile? initialUser;

  const UserForm({
    super.key,
    this.initialUser,
  });

  bool get isEditMode => initialUser != null;

  @override
  ConsumerState<UserForm> createState() => _UserFormState();
}

class _UserFormState extends ConsumerState<UserForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _pinCtrl;
  late final FocusNode _nameFocusNode;
  late String _phoneDigits;
  late AppRole _selectedRole;
  _UserFormKeypadTarget _keypadTarget = _UserFormKeypadTarget.none;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = widget.initialUser;
    _nameCtrl = TextEditingController(text: user?.fullName ?? '');
    _phoneDigits = user != null
        ? UzbekPhoneMaskFormatter.extract9Digits(user.phone)
        : '';
    _phoneCtrl = TextEditingController(
      text: formatUzbekPhoneMask(_phoneDigits),
    );
    _pinCtrl = TextEditingController();
    _selectedRole = user?.role ?? AppRole.user;
    _nameFocusNode = FocusNode()
      ..addListener(() {
        if (_nameFocusNode.hasFocus &&
            _keypadTarget != _UserFormKeypadTarget.none) {
          setState(() => _keypadTarget = _UserFormKeypadTarget.none);
        }
      });
  }

  @override
  void dispose() {
    _nameFocusNode.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  String? _resolveCurrentUserId() {
    final profileId = ref.watch(currentProfileProvider).asData?.value?.id;
    if (profileId != null) return profileId;
    try {
      return ref.read(authRepoProvider).currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  void _activateKeypad(_UserFormKeypadTarget target) {
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    setState(() => _keypadTarget = target);
  }

  void _syncPhoneFromDigits() {
    final formatted = formatUzbekPhoneMask(_phoneDigits);
    _phoneCtrl.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  void _onKeypadDigit(String digit) {
    if (_isSaving) return;
    if (_keypadTarget == _UserFormKeypadTarget.phone) {
      if (_phoneDigits.length >= 9) return;
      setState(() {
        _phoneDigits += digit;
        _syncPhoneFromDigits();
      });
    } else if (_keypadTarget == _UserFormKeypadTarget.pin) {
      if (_pinCtrl.text.length >= 5) return;
      setState(() {
        final next = '${_pinCtrl.text}$digit';
        _pinCtrl.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
      });
    }
  }

  void _onKeypadBackspace() {
    if (_isSaving) return;
    if (_keypadTarget == _UserFormKeypadTarget.phone) {
      // Sync digits in case text was entered directly in a test
      _phoneDigits = UzbekPhoneMaskFormatter.extract9Digits(_phoneCtrl.text);
      if (_phoneDigits.isEmpty) return;
      setState(() {
        _phoneDigits = _phoneDigits.substring(0, _phoneDigits.length - 1);
        _syncPhoneFromDigits();
      });
    } else if (_keypadTarget == _UserFormKeypadTarget.pin) {
      final cur = _pinCtrl.text;
      if (cur.isEmpty) return;
      setState(() {
        final next = cur.substring(0, cur.length - 1);
        _pinCtrl.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
      });
    }
  }

  void _onKeypadClearAll() {
    if (_isSaving) return;
    if (_keypadTarget == _UserFormKeypadTarget.phone) {
      setState(() {
        _phoneDigits = '';
        _syncPhoneFromDigits();
      });
    } else if (_keypadTarget == _UserFormKeypadTarget.pin) {
      setState(() {
        _pinCtrl.clear();
      });
    }
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(adminUsersRepoProvider);
      if (widget.isEditMode) {
        final isSelf = widget.initialUser!.id == _resolveCurrentUserId();
        await repo.updateUser(
          userId: widget.initialUser!.id,
          fullName: _nameCtrl.text.trim(),
          role: isSelf ? null : _selectedRole,
        );
      } else {
        final normalized = normalizePhone(_phoneCtrl.text.trim());
        if (normalized == null) {
          throw const AppException('Telefon raqam noto\'g\'ri');
        }
        await repo.createUser(
          phone: normalized,
          fullName: _nameCtrl.text.trim(),
          pin: _pinCtrl.text.trim(),
          role: _selectedRole,
        );
      }

      ref.invalidate(adminUsersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditMode
                  ? 'Foydalanuvchi ma\'lumotlari yangilandi'
                  : 'Yangi foydalanuvchi qo\'shildi',
            ),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mapErrorToMessage(e))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = _resolveCurrentUserId();
    final isEditingSelf =
        widget.isEditMode &&
        currentUserId != null &&
        widget.initialUser?.id == currentUserId;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: bottomInset + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.isEditMode
                          ? 'Foydalanuvchini tahrirlash'
                          : 'Yangi foydalanuvchi qo\'shish',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                    tooltip: 'Yopish',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('user_form_full_name'),
                controller: _nameCtrl,
                focusNode: _nameFocusNode,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'F.I.O (To\'liq ism) *',
                  hintText: 'Masalan: Aliyev Vali',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: FormValidators.validateFullName,
              ),
              const SizedBox(height: 12),
              if (!widget.isEditMode) ...[
                TextFormField(
                  key: const ValueKey('user_form_phone'),
                  controller: _phoneCtrl,
                  readOnly: true,
                  showCursor: true,
                  enableInteractiveSelection: false,
                  onTap: () => _activateKeypad(_UserFormKeypadTarget.phone),
                  inputFormatters: const [UzbekPhoneMaskFormatter()],
                  decoration: InputDecoration(
                    labelText: 'Telefon raqami *',
                    hintText: '+998 (90) 123-45-67',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    suffixIcon: _phoneDigits.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            tooltip: 'Tozalash',
                            onPressed: _isSaving
                                ? null
                                : () {
                                    setState(() {
                                      _phoneDigits = '';
                                      _syncPhoneFromDigits();
                                    });
                                  },
                          )
                        : null,
                  ),
                  validator: FormValidators.validateRequiredPhone,
                ),
                const SizedBox(height: 12),
              ],
              if (!isEditingSelf)
                DropdownButtonFormField<AppRole>(
                  key: const ValueKey('user_form_role'),
                  initialValue: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Rol',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: AppRole.user,
                      child: Text('Xodim'),
                    ),
                    DropdownMenuItem(
                      value: AppRole.admin,
                      child: Text('Admin'),
                    ),
                  ],
                  onChanged: _isSaving
                      ? null
                      : (v) {
                          if (v != null) {
                            setState(() => _selectedRole = v);
                          }
                        },
                ),
              if (!widget.isEditMode) ...[
                if (!isEditingSelf) const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('user_form_pin'),
                  controller: _pinCtrl,
                  readOnly: true,
                  showCursor: true,
                  enableInteractiveSelection: false,
                  onTap: () => _activateKeypad(_UserFormKeypadTarget.pin),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(5),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Boshlang\'ich PIN kod (5 raqam) *',
                    hintText: '12345',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: FormValidators.validatePin,
                ),
              ],
              if (_keypadTarget != _UserFormKeypadTarget.none) ...[
                const SizedBox(height: 12),
                NumericKeypad(
                  enabled: !_isSaving,
                  onDigitPressed: _onKeypadDigit,
                  onBackspace: _onKeypadBackspace,
                  onClearAll: _onKeypadClearAll,
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Bekor qilish'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('user_form_save_btn'),
                      onPressed: _isSaving ? null : _submit,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: const Text('Saqlash'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog / sheet for resetting a user's 5-digit PIN with custom keypad + 5 PIN boxes.
class UserResetPinDialog extends ConsumerStatefulWidget {
  final Profile user;

  const UserResetPinDialog({
    super.key,
    required this.user,
  });

  @override
  ConsumerState<UserResetPinDialog> createState() => _UserResetPinDialogState();
}

class _UserResetPinDialogState extends ConsumerState<UserResetPinDialog> {
  String _pin = '';
  bool _isSaving = false;
  String? _errorText;
  int _shakeTrigger = 0;

  void _onDigit(String digit) {
    if (_isSaving || _pin.length >= 5) return;
    setState(() {
      _pin += digit;
      _errorText = null;
    });
  }

  void _onBackspace() {
    if (_isSaving || _pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _errorText = null;
    });
  }

  void _onClearAll() {
    if (_isSaving || _pin.isEmpty) return;
    setState(() {
      _pin = '';
      _errorText = null;
    });
  }

  Future<void> _submit() async {
    final validationError = FormValidators.validatePin(_pin);
    if (validationError != null) {
      setState(() {
        _errorText = validationError;
        _shakeTrigger++;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      await ref.read(adminUsersRepoProvider).resetPin(
            userId: widget.user.id,
            pin: _pin,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.user.fullName} uchun PIN yangilandi'),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = mapErrorToMessage(e);
          _shakeTrigger++;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'PIN kodni tiklash',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.user.fullName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              PinBoxes(
                pin: _pin,
                hasError: _errorText != null,
                isActive: !_isSaving,
                shakeTrigger: _shakeTrigger,
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorText!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              NumericKeypad(
                enabled: !_isSaving,
                onDigitPressed: _onDigit,
                onBackspace: _onBackspace,
                onClearAll: _onClearAll,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Bekor qilish'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('reset_pin_confirm_btn'),
                      onPressed: (_isSaving || _pin.length != 5)
                          ? null
                          : _submit,
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Saqlash'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
