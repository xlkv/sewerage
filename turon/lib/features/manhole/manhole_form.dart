import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../core/geo_utils.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../data/models/manhole.dart';
import '../../data/models/master.dart';
import '../../data/models/work_status.dart';
import '../../data/repositories/manhole_repo.dart';

class ManholeForm extends ConsumerStatefulWidget {
  /// Non-null when editing an existing manhole; null when creating a new one.
  final Manhole? existing;

  /// Coordinates used when creating a new manhole.
  final double? initialLat;
  final double? initialLng;

  final List<Master> masters;
  final void Function(Manhole saved) onSaved;
  final VoidCallback onCancel;

  const ManholeForm({
    super.key,
    this.existing,
    this.initialLat,
    this.initialLng,
    required this.masters,
    required this.onSaved,
    required this.onCancel,
  });

  @override
  ConsumerState<ManholeForm> createState() => _ManholeFormState();
}

class _ManholeFormState extends ConsumerState<ManholeForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _heightController;
  late final TextEditingController _diameterController;
  late final TextEditingController _groundController;
  late final TextEditingController _invertController;
  late final TextEditingController _noteController;

  /// Depth = ground − invert when both elevations are entered.
  double? get _derivedDepth {
    final g = FormValidators.parseOptionalDecimal(_groundController.text);
    final i = FormValidators.parseOptionalDecimal(_invertController.text);
    if (g == null || i == null || g <= i) return null;
    return double.parse((g - i).toStringAsFixed(2));
  }

  void _onElevationChanged() {
    final d = _derivedDepth;
    if (d != null) _heightController.text = d.toStringAsFixed(2);
    setState(() {});
  }

  late WorkStatus _status;
  String? _selectedMasterId;
  bool _saving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _codeController = TextEditingController(text: e?.code ?? '');
    _heightController = TextEditingController(
      text: e?.heightM != null ? e!.heightM.toString() : '',
    );
    _diameterController = TextEditingController(
      text: e?.diameterM != null ? e!.diameterM.toString() : '',
    );
    _groundController = TextEditingController(
      text: e?.groundElev?.toStringAsFixed(2) ?? '',
    );
    _invertController = TextEditingController(
      text: e?.invertElev?.toStringAsFixed(2) ?? '',
    );
    _noteController = TextEditingController(text: e?.note ?? '');
    _status = e?.status ?? WorkStatus.planned;
    _selectedMasterId = e?.masterId;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _heightController.dispose();
    _groundController.dispose();
    _invertController.dispose();
    _diameterController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _errorText = null;
    });

    final codeText = _codeController.text.trim();
    final code = codeText.isEmpty ? null : codeText;
    final heightM = FormValidators.parseOptionalDecimal(_heightController.text);
    final diameterM = FormValidators.parseOptionalDecimal(
      _diameterController.text,
    );
    final groundElev = FormValidators.parseOptionalDecimal(
      _groundController.text,
    );
    final invertElev = FormValidators.parseOptionalDecimal(
      _invertController.text,
    );
    final noteText = _noteController.text.trim();
    final note = noteText.isEmpty ? null : noteText;

    try {
      final repo = ref.read(manholeRepoProvider);
      final Manhole saved;
      if (widget.existing == null) {
        saved = await repo.create(
          lat: widget.initialLat ?? GeoUtils.qarshiLat,
          lng: widget.initialLng ?? GeoUtils.qarshiLng,
          code: code,
          status: _status,
          heightM: heightM,
          diameterM: diameterM,
          groundElev: groundElev,
          invertElev: invertElev,
          masterId: _selectedMasterId,
          note: note,
        );
      } else {
        saved = await repo.update(
          widget.existing!.id,
          code: code,
          status: _status,
          heightM: heightM,
          clearHeight: heightM == null,
          diameterM: diameterM,
          clearDiameter: diameterM == null,
          groundElev: groundElev,
          clearGroundElev: groundElev == null,
          invertElev: invertElev,
          clearInvertElev: invertElev == null,
          masterId: _selectedMasterId,
          clearMaster: _selectedMasterId == null,
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
    final lat = widget.existing?.lat ?? widget.initialLat ?? 0;
    final lng = widget.existing?.lng ?? widget.initialLng ?? 0;

    final selectableMasters = widget.masters
        .where((m) => m.isActive || m.id == _selectedMasterId)
        .toList();

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
                      ? 'Kolodetsni tahrirlash (${widget.existing!.code})'
                      : 'Yangi kolodets qo\'shish',
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
          Text(
            'Koordinata: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade700,
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
              hintText: 'Bo\'sh qolsa avto (K-1, K-2…)',
              helperText: isEdit ? null : 'Bo\'sh qolsa avto (K-1, K-2…)',
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  key: const ValueKey('manhole_ground_elev'),
                  controller: _groundController,
                  decoration: const InputDecoration(
                    labelText: 'Yer sathi (m)',
                    hintText: 'Masalan: 85.73',
                    helperText: 'Boltiq tizimi',
                    prefixText: '+',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  onChanged: (_) => _onElevationChanged(),
                  validator: FormValidators.validateElevation,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  key: const ValueKey('manhole_invert_elev'),
                  controller: _invertController,
                  decoration: const InputDecoration(
                    labelText: 'Quvur osti (m)',
                    hintText: 'Masalan: 82.73',
                    helperText: 'Boltiq tizimi',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  onChanged: (_) => _onElevationChanged(),
                  validator: (v) {
                    final base = FormValidators.validateElevation(v);
                    if (base != null) return base;
                    final g = FormValidators.parseOptionalDecimal(
                      _groundController.text,
                    );
                    final i = FormValidators.parseOptionalDecimal(v);
                    if (g != null && i != null && i >= g) {
                      return 'Yer sathidan past bo\'lishi kerak';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _heightController,
                  readOnly: _derivedDepth != null,
                  decoration: InputDecoration(
                    labelText: 'Chuqurligi (m)',
                    hintText: 'Masalan: 2.5',
                    helperText: _derivedDepth != null
                        ? 'Otmetkalardan avtomatik'
                        : null,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: FormValidators.validateManholeHeight,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _diameterController,
                  decoration: const InputDecoration(
                    labelText: 'Diametr (m)',
                    hintText: 'Masalan: 1.0',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: FormValidators.validateManholeDiameterM,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            initialValue: selectableMasters.any((m) => m.id == _selectedMasterId)
                ? _selectedMasterId
                : null,
            decoration: const InputDecoration(
              labelText: 'Biriktirilgan usta',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('— Tanlanmagan —'),
              ),
              ...selectableMasters.map(
                (m) => DropdownMenuItem<String?>(
                  value: m.id,
                  child: Text(
                    m.phone != null && m.phone!.isNotEmpty
                        ? '${m.fullName} (${m.phone})'
                        : m.fullName,
                  ),
                ),
              ),
            ],
            onChanged: (val) => setState(() => _selectedMasterId = val),
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
