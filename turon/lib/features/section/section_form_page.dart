import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/errors.dart';
import '../../core/geo_utils.dart';
import '../../core/theme.dart';
import '../../data/models/section.dart';
import '../../data/models/work_status.dart';
import '../../data/repositories/section_repo.dart';
import 'section_stats.dart';

/// Name, note, status and dates of a section whose pipes were picked on the
/// map. Pops with the saved section id.
class SectionFormPage extends ConsumerStatefulWidget {
  final Section? section;
  final Set<String> pipeIds;
  final Set<String> manholeIds;
  final SectionStats stats;

  const SectionFormPage({
    super.key,
    this.section,
    required this.pipeIds,
    required this.manholeIds,
    required this.stats,
  });

  @override
  ConsumerState<SectionFormPage> createState() => _SectionFormPageState();
}

class _SectionFormPageState extends ConsumerState<SectionFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.section?.name);
  late final _note = TextEditingController(text: widget.section?.note);
  late WorkStatus _status = widget.section?.status ?? WorkStatus.planned;
  late DateTime? _start = widget.section?.startDate;
  late DateTime? _end = widget.section?.endDate;
  bool _saving = false;

  static final _dateFmt = DateFormat('d-MMMM, yyyy', 'uz');

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (start ? _start : _end) ?? _start ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
        if (_end != null && _end!.isBefore(picked)) _end = picked;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final id = await ref
          .read(sectionRepoProvider)
          .save(
            id: widget.section?.id,
            name: _name.text,
            note: _note.text,
            status: _status,
            startDate: _start,
            endDate: _end,
            pipeIds: widget.pipeIds,
            manholeIds: widget.manholeIds,
          );
      if (mounted) Navigator.of(context).pop(id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mapErrorToMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.stats;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.section == null ? 'Yangi uchastka' : 'Uchastkani tahrirlash',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.route_rounded, color: AppColors.brand),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${formatLength(s.lengthM)} · ${s.pipeCount} quvur · '
                        '${s.manholeCount} kolodets',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              autofocus: widget.section == null,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Nomi',
                hintText: 'Masalan: 3-uchastka, Navoiy ko\'chasi',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nomini kiriting' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _note,
              minLines: 2,
              maxLines: 5,
              maxLength: 2000,
              decoration: const InputDecoration(labelText: 'Izoh'),
            ),
            const SizedBox(height: 12),
            const Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<WorkStatus>(
              segments: [
                for (final st in WorkStatus.values)
                  ButtonSegment(
                    value: st,
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(st.label, maxLines: 1),
                    ),
                  ),
              ],
              selected: {_status},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => _status = v.first),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'Boshlanish',
                    value: _start == null ? null : _dateFmt.format(_start!),
                    onTap: () => _pickDate(start: true),
                    onClear: () => setState(() => _start = null),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateField(
                    label: 'Tugash',
                    value: _end == null ? null : _dateFmt.format(_end!),
                    onTap: () => _pickDate(start: false),
                    onClear: () => setState(() => _end = null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded, size: 18),
              label: const Text('Saqlash'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.button),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: value == null
              ? const Icon(Icons.event_outlined, size: 18)
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: onClear,
                ),
        ),
        child: Text(
          value ?? '—',
          style: TextStyle(color: value == null ? AppColors.muted : null),
        ),
      ),
    );
  }
}
