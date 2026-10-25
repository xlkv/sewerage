import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../core/geo_utils.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../data/models/manhole.dart';
import '../../data/models/pipe.dart';
import '../../data/models/work_status.dart';
import '../../data/repositories/pipe_repo.dart';

class PipeForm extends ConsumerStatefulWidget {
  /// Non-null when editing an existing pipe; null when creating a new pipe.
  final Pipe? existing;

  /// Endpoint manhole IDs when creating a new pipe.
  final String? initialFromManholeId;
  final String? initialToManholeId;

  final Map<String, Manhole> allManholes;
  final void Function(Pipe saved) onSaved;
  final VoidCallback onCancel;

  const PipeForm({
    super.key,
    this.existing,
    this.initialFromManholeId,
    this.initialToManholeId,
    required this.allManholes,
    required this.onSaved,
    required this.onCancel,
  });

  @override
  ConsumerState<PipeForm> createState() => _PipeFormState();
}

class _PipeFormState extends ConsumerState<PipeForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _customDiameterController;
  late final TextEditingController _manualLengthController;
  late final TextEditingController _noteController;

  late String _fromManholeId;
  late String _toManholeId;
  late WorkStatus _status;
  late int _selectedStandardDiameter;
  bool _isCustomDiameter = false;
  bool _isManualLength = false;
  bool _saving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _fromManholeId = e?.fromManholeId ?? widget.initialFromManholeId ?? '';
    _toManholeId = e?.toManholeId ?? widget.initialToManholeId ?? '';
    _codeController = TextEditingController(text: e?.code ?? '');
    _noteController = TextEditingController(text: e?.note ?? '');
    _status = e?.status ?? WorkStatus.planned;

    final existingDia = e?.diameterMm;
    if (existingDia != null) {
      if (FormValidators.standardPipeDiameters.contains(existingDia)) {
        _selectedStandardDiameter = existingDia;
        _isCustomDiameter = false;
        _customDiameterController = TextEditingController();
      } else {
        _selectedStandardDiameter = 200;
        _isCustomDiameter = true;
        _customDiameterController = TextEditingController(
          text: existingDia.toString(),
        );
      }
    } else {
      _selectedStandardDiameter = 200;
      _isCustomDiameter = false;
      _customDiameterController = TextEditingController();
    }

    _isManualLength = e?.lengthManualM != null;
    _manualLengthController = TextEditingController(
      text: e?.lengthManualM != null ? e!.lengthManualM.toString() : '',
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _customDiameterController.dispose();
    _manualLengthController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double? _computeAutoPreviewLength() {
    final from = widget.allManholes[_fromManholeId];
    final to = widget.allManholes[_toManholeId];
    if (from == null || to == null) {
      return widget.existing?.lengthAutoM;
    }
    return GeoUtils.spheroidMetersRounded(
      from.lat,
      from.lng,
      to.lat,
      to.lng,
    );
  }

  void _swapDirection() {
    setState(() {
      final tmp = _fromManholeId;
      _fromManholeId = _toManholeId;
      _toManholeId = tmp;
    });
  }

  void _revertToAutoLength() {
    setState(() {
      _isManualLength = false;
      _manualLengthController.clear();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _errorText = null;
    });

    final codeText = _codeController.text.trim();
    final code = codeText.isEmpty ? null : codeText;
    final int diameterMm = _isCustomDiameter
        ? int.parse(_customDiameterController.text.trim())
        : _selectedStandardDiameter;

    final double? lengthManualM = _isManualLength
        ? FormValidators.parseOptionalDecimal(_manualLengthController.text)
        : null;

    final noteText = _noteController.text.trim();
    final note = noteText.isEmpty ? null : noteText;

    try {
      final repo = ref.read(pipeRepoProvider);
      final Pipe saved;
      if (widget.existing == null) {
        saved = await repo.create(
          fromManholeId: _fromManholeId,
          toManholeId: _toManholeId,
          diameterMm: diameterMm,
          code: code,
          status: _status,
          lengthManualM: lengthManualM,
          note: note,
        );
      } else {
        saved = await repo.update(
          widget.existing!.id,
          code: code,
          fromManholeId: _fromManholeId,
          toManholeId: _toManholeId,
          // Bends follow the flow direction; reverse them when swapped.
          path: _fromManholeId == widget.existing!.toManholeId
              ? widget.existing!.reversedPath
              : null,
          status: _status,
          diameterMm: diameterMm,
          lengthManualM: lengthManualM,
          clearManualLength: !_isManualLength || lengthManualM == null,
          note: note,
          clearNote: note == null,
        );
      }
      if (!mounted) return;
      widget.onSaved(saved);
    } catch (e) {
      if (!mounted) return;
      final msg = mapErrorToMessage(e);
      setState(() => _errorText = msg);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final fromCode = widget.allManholes[_fromManholeId]?.code ?? _fromManholeId;
    final toCode = widget.allManholes[_toManholeId]?.code ?? _toManholeId;
    final autoPreview = _computeAutoPreviewLength();

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isEdit
                      ? 'Quvurni tahrirlash (${widget.existing!.code})'
                      : 'Yangi quvur qo\'shish',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: _saving ? null : widget.onCancel,
                icon: const Icon(Icons.close),
                tooltip: 'Bekor qilish',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            color: Colors.blueGrey.shade50,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.route, size: 20, color: Color(0xFF0D47A1)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Chip(
                            label: Text(
                              fromCode,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(Icons.arrow_forward, size: 18),
                          ),
                          Chip(
                            label: Text(
                              toCode,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('pipe_form_swap_btn'),
                    tooltip: 'Yo\'nalishni almashtirish',
                    onPressed: _saving ? null : _swapDirection,
                    icon: const Icon(Icons.swap_horiz),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_errorText != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                _errorText!,
                style: TextStyle(color: Colors.red.shade800),
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _codeController,
            decoration: InputDecoration(
              labelText: isEdit ? 'Kod *' : 'Kod',
              hintText: 'Bo\'sh qolsa avto (Q-1, Q-2…)',
              helperText: isEdit ? null : 'Bo\'sh qolsa avto (Q-1, Q-2…)',
              border: const OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.characters,
            validator: (val) =>
                FormValidators.validateCode(val, allowEmpty: !isEdit),
          ),
          const SizedBox(height: 16),
          Text('Holat *', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: WorkStatus.values.map((s) {
              final selected = _status == s;
              final statusColor = AppColors.forStatus(s);
              return ChoiceChip(
                label: Text(s.label),
                selected: selected,
                selectedColor: statusColor.withValues(alpha: 0.2),
                avatar: CircleAvatar(backgroundColor: statusColor, radius: 6),
                onSelected: (_) => setState(() => _status = s),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text('Diametr (mm) *', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...FormValidators.standardPipeDiameters.map((dia) {
                final selected =
                    !_isCustomDiameter && _selectedStandardDiameter == dia;
                return ChoiceChip(
                  label: Text('$dia'),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _isCustomDiameter = false;
                      _selectedStandardDiameter = dia;
                    });
                  },
                );
              }),
              ChoiceChip(
                label: const Text('Boshqa'),
                selected: _isCustomDiameter,
                onSelected: (_) {
                  setState(() {
                    _isCustomDiameter = true;
                  });
                },
              ),
            ],
          ),
          if (_isCustomDiameter) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _customDiameterController,
              decoration: const InputDecoration(
                labelText: 'Boshqa diametr (50..2000 mm) *',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (val) => FormValidators.validatePipeCustomDiameter(
                val,
                isCustomSelected: _isCustomDiameter,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.straighten, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        autoPreview != null
                            ? 'Avto uzunlik (GPS): \u2248 ${formatLength(autoPreview)}'
                            : 'Avto uzunlik (GPS): hisoblanadi',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (_isManualLength)
                      TextButton.icon(
                        onPressed: _saving ? null : _revertToAutoLength,
                        icon: const Icon(Icons.restore, size: 16),
                        label: const Text('Avtoga qaytarish'),
                      ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Qo\'lda uzunlik kiritish'),
                  value: _isManualLength,
                  onChanged: (val) {
                    setState(() => _isManualLength = val);
                  },
                ),
                if (_isManualLength)
                  TextFormField(
                    controller: _manualLengthController,
                    decoration: const InputDecoration(
                      labelText: 'Qo\'lda uzunlik (m) *',
                      hintText: '0..10000',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (val) => FormValidators.validatePipeManualLength(
                      val,
                      isManualEnabled: _isManualLength,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Izoh',
              hintText: 'Qo\'shimcha ma\'lumot (maks. 500 belgi)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            validator: FormValidators.validateNote,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : widget.onCancel,
                  child: const Text('Bekor qilish'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
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
    );
  }
}
