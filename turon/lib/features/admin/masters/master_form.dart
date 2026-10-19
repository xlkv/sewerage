import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth_utils.dart';
import '../../../core/errors.dart';
import '../../../core/validators.dart';
import '../../../data/models/master.dart';
import '../../../data/repositories/master_repo.dart';
import '../../../shared/widgets/numeric_keypad.dart';
import '../users/user_form.dart';

/// Bottom sheet / dialog form for creating or editing a master (`masters` table).
class MasterForm extends ConsumerStatefulWidget {
  final Master? initialMaster;

  const MasterForm({
    super.key,
    this.initialMaster,
  });

  bool get isEditMode => initialMaster != null;

  @override
  ConsumerState<MasterForm> createState() => _MasterFormState();
}

class _MasterFormState extends ConsumerState<MasterForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final FocusNode _nameFocusNode;
  late String _phoneDigits;
  late bool _isActive;
  bool _showKeypad = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final master = widget.initialMaster;
    _nameCtrl = TextEditingController(text: master?.fullName ?? '');
    final rawPhone = master?.phone ?? '';
    _phoneDigits = UzbekPhoneMaskFormatter.extract9Digits(rawPhone);
    _phoneCtrl = TextEditingController(
      text: formatUzbekPhoneMask(_phoneDigits),
    );
    _isActive = master?.isActive ?? true;
    _nameFocusNode = FocusNode()
      ..addListener(() {
        if (_nameFocusNode.hasFocus && _showKeypad) {
          setState(() => _showKeypad = false);
        }
      });
  }

  @override
  void dispose() {
    _nameFocusNode.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _activatePhoneKeypad() {
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    setState(() => _showKeypad = true);
  }

  void _syncPhoneFromDigits() {
    final formatted = formatUzbekPhoneMask(_phoneDigits);
    _phoneCtrl.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  void _onPhoneDigit(String digit) {
    if (_isSaving || _phoneDigits.length >= 9) return;
    setState(() {
      _phoneDigits += digit;
      _syncPhoneFromDigits();
    });
  }

  void _onPhoneBackspace() {
    if (_isSaving) return;
    _phoneDigits = UzbekPhoneMaskFormatter.extract9Digits(_phoneCtrl.text);
    if (_phoneDigits.isEmpty) return;
    setState(() {
      _phoneDigits = _phoneDigits.substring(0, _phoneDigits.length - 1);
      _syncPhoneFromDigits();
    });
  }

  void _onPhoneClearAll() {
    if (_isSaving) return;
    setState(() {
      _phoneDigits = '';
      _syncPhoneFromDigits();
    });
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(masterRepoProvider);
      final rawPhone = _phoneCtrl.text.trim();
      final digits = UzbekPhoneMaskFormatter.extract9Digits(rawPhone);
      final String? normalizedPhone = digits.isEmpty
          ? null
          : normalizePhone(rawPhone);

      if (widget.isEditMode) {
        await repo.update(
          widget.initialMaster!.id,
          fullName: _nameCtrl.text.trim(),
          phone: normalizedPhone,
          clearPhone: normalizedPhone == null,
          isActive: _isActive,
        );
      } else {
        await repo.create(
          fullName: _nameCtrl.text.trim(),
          phone: normalizedPhone,
          isActive: _isActive,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditMode
                  ? 'Usta ma\'lumotlari yangilandi'
                  : 'Yangi usta qo\'shildi',
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
                          ? 'Ustani tahrirlash'
                          : 'Yangi usta qo\'shish',
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
                key: const ValueKey('master_form_full_name'),
                controller: _nameCtrl,
                focusNode: _nameFocusNode,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'F.I.O (To\'liq ism) *',
                  hintText: 'Masalan: Karimov Anvar',
                  prefixIcon: Icon(Icons.engineering_outlined),
                ),
                validator: FormValidators.validateFullName,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('master_form_phone'),
                controller: _phoneCtrl,
                readOnly: true,
                showCursor: true,
                enableInteractiveSelection: false,
                onTap: _activatePhoneKeypad,
                inputFormatters: const [UzbekPhoneMaskFormatter()],
                decoration: InputDecoration(
                  labelText: 'Telefon raqami (ixtiyoriy)',
                  hintText: '+998 (90) 123-45-67',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  suffixIcon: _phoneDigits.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          tooltip: 'Tozalash',
                          onPressed: _isSaving ? null : _onPhoneClearAll,
                        )
                      : null,
                ),
                validator: FormValidators.validateOptionalPhone,
              ),
              if (_showKeypad) ...[
                const SizedBox(height: 10),
                NumericKeypad(
                  enabled: !_isSaving,
                  onDigitPressed: _onPhoneDigit,
                  onBackspace: _onPhoneBackspace,
                  onClearAll: _onPhoneClearAll,
                ),
              ],
              const SizedBox(height: 8),
              SwitchListTile(
                key: const ValueKey('master_form_is_active'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Faol holatda'),
                subtitle: Text(_isActive ? 'Faol' : 'Nofaol'),
                value: _isActive,
                onChanged: _isSaving
                    ? null
                    : (v) => setState(() => _isActive = v),
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
                    child: FilledButton.icon(
                      key: const ValueKey('master_form_save_btn'),
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
