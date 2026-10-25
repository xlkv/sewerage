import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../core/geo_utils.dart';
import '../../core/theme.dart';
import '../../data/models/manhole.dart';
import '../../data/models/pipe.dart';
import '../../data/repositories/manhole_repo.dart';
import '../../data/repositories/pipe_repo.dart';

/// Where a new manhole lands when placed [meters] from [from] along [pipe].
/// Bend points are returned in the pipe's from → to direction.
({double lat, double lng, List<List<double>> pathA, List<List<double>> pathB})
insertPointOnPipe({
  required Pipe pipe,
  required Manhole pipeFrom,
  required Manhole pipeTo,
  required String fromManholeId,
  required double meters,
}) {
  final pts = [
    (lat: pipeFrom.lat, lng: pipeFrom.lng),
    for (final v in pipe.path) (lat: v[0], lng: v[1]),
    (lat: pipeTo.lat, lng: pipeTo.lng),
  ];
  final total = GeoUtils.polylineMeters(pts);
  final fromStart = fromManholeId == pipe.fromManholeId
      ? meters
      : total - meters;
  final s = GeoUtils.splitPolyline(pts, fromStart);
  return (lat: s.lat, lng: s.lng, pathA: s.before, pathB: s.after);
}

/// Admin sheet: pick a connected pipe and a distance; a manhole is inserted
/// there and the pipe is split in two. Returns the new manhole id.
Future<String?> showInsertManholeSheet(
  BuildContext context, {
  required Manhole manhole,
  required Map<String, Manhole> allManholes,
  required Map<String, Pipe> allPipes,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _InsertManholeSheet(
      manhole: manhole,
      allManholes: allManholes,
      allPipes: allPipes,
    ),
  );
}

class _Option {
  final Pipe pipe;
  final Manhole other;
  final double lengthM;
  const _Option(this.pipe, this.other, this.lengthM);
}

class _InsertManholeSheet extends ConsumerStatefulWidget {
  final Manhole manhole;
  final Map<String, Manhole> allManholes;
  final Map<String, Pipe> allPipes;

  const _InsertManholeSheet({
    required this.manhole,
    required this.allManholes,
    required this.allPipes,
  });

  @override
  ConsumerState<_InsertManholeSheet> createState() =>
      _InsertManholeSheetState();
}

class _InsertManholeSheetState extends ConsumerState<_InsertManholeSheet> {
  late final List<_Option> _options;
  final _distance = TextEditingController();
  int _selected = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final m = widget.manhole;
    _options = [
      for (final p in widget.allPipes.values)
        if (p.fromManholeId == m.id || p.toManholeId == m.id)
          if (widget.allManholes[p.fromManholeId] case final a?)
            if (widget.allManholes[p.toManholeId] case final b?)
              _Option(
                p,
                p.fromManholeId == m.id ? b : a,
                GeoUtils.polylineMeters([
                  (lat: a.lat, lng: a.lng),
                  for (final v in p.path) (lat: v[0], lng: v[1]),
                  (lat: b.lat, lng: b.lng),
                ]),
              ),
    ]..sort((x, y) => x.other.code.compareTo(y.other.code));
    _setDefaultDistance();
  }

  void _setDefaultDistance() {
    if (_options.isEmpty) return;
    final len = _options[_selected].lengthM;
    final d = len > 60 ? 50.0 : (len / 2).floorToDouble();
    _distance.text = d.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _distance.dispose();
    super.dispose();
  }

  double? get _meters => double.tryParse(_distance.text.replaceAll(',', '.'));

  String? get _error {
    final d = _meters;
    if (d == null) return 'Masofani kiriting';
    final len = _options[_selected].lengthM;
    if (d < 1 || d > len - 1) {
      return '1 … ${(len - 1).toStringAsFixed(0)} m oralig\'ida bo\'lsin';
    }
    return null;
  }

  Future<void> _save() async {
    if (_error != null) return;
    final o = _options[_selected];
    final p = o.pipe;
    final pt = insertPointOnPipe(
      pipe: p,
      pipeFrom: widget.allManholes[p.fromManholeId]!,
      pipeTo: widget.allManholes[p.toManholeId]!,
      fromManholeId: widget.manhole.id,
      meters: _meters!,
    );
    setState(() => _saving = true);
    try {
      final id = await ref
          .read(pipeRepoProvider)
          .splitPipe(
            p.id,
            lat: pt.lat,
            lng: pt.lng,
            pathA: pt.pathA,
            pathB: pt.pathB,
          );
      await ref.read(manholeRepoProvider).fetchOne(id);
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
    final m = widget.manhole;
    final theme = Theme.of(context);
    if (_options.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Text('Bu kolodetsga quvur ulanmagan.'),
      );
    }
    final o = _options[_selected];
    final d = _meters;
    final error = _error;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Oraliq kolodets qo\'shish', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text(
            'Quvur ikkiga bo\'linadi, uzunliklar qayta hisoblanadi.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          const Text(
            'Qaysi tomonga',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (var i = 0; i < _options.length; i++)
                  _DirectionTile(
                    selected: i == _selected,
                    title:
                        '${m.code} → ${_options[i].other.code}  ·  ${_options[i].pipe.code}',
                    subtitle:
                        '${formatLength(_options[i].lengthM)} · Ø${_options[i].pipe.diameterMm}',
                    onTap: () => setState(() {
                      _selected = i;
                      _setDefaultDistance();
                    }),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _distance,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              labelText: '${m.code} dan masofa',
              suffixText: 'm',
              errorText: error,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final v in [25, 50, 100])
                if (v < o.lengthM - 1)
                  ActionChip(
                    label: Text('$v m'),
                    onPressed: () =>
                        setState(() => _distance.text = v.toString()),
                  ),
              ActionChip(
                label: const Text('O\'rtasi'),
                onPressed: () => setState(
                  () => _distance.text = (o.lengthM / 2).toStringAsFixed(1),
                ),
              ),
            ],
          ),
          if (error == null && d != null) ...[
            const SizedBox(height: 10),
            _SplitPreview(
              fromCode: m.code,
              toCode: o.other.code,
              first: d,
              second: o.lengthM - d,
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving || error != null ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_location_alt_outlined, size: 18),
            label: const Text('Qo\'shish'),
          ),
        ],
      ),
    );
  }
}

class _DirectionTile extends StatelessWidget {
  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DirectionTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      color: selected ? scheme.primaryContainer : null,
      child: ListTile(
        dense: true,
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        leading: Icon(
          selected ? Icons.check_circle_rounded : Icons.circle_outlined,
          color: selected ? scheme.primary : AppColors.muted,
        ),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}

/// `K-5 ●── 50 m ──◆── 262 m ──● K-12`
class _SplitPreview extends StatelessWidget {
  final String fromCode;
  final String toCode;
  final double first;
  final double second;

  const _SplitPreview({
    required this.fromCode,
    required this.toCode,
    required this.first,
    required this.second,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final total = first + second;
    Widget dot(Color c, double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    );
    Widget seg(double m) => Expanded(
      flex: (m / total * 1000).round().clamp(1, 1000),
      child: Column(
        children: [
          Text(
            formatLength(m),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Container(height: 3, color: AppColors.muted.withValues(alpha: 0.5)),
          const SizedBox(height: 18),
        ],
      ),
    );
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 14.5),
              child: dot(AppColors.muted, 10),
            ),
            seg(first),
            Padding(
              padding: const EdgeInsets.only(bottom: 12.5),
              child: dot(primary, 14),
            ),
            seg(second),
            Padding(
              padding: const EdgeInsets.only(bottom: 14.5),
              child: dot(AppColors.muted, 10),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(fromCode, style: const TextStyle(color: AppColors.muted)),
            Text('yangi', style: TextStyle(color: primary)),
            Text(toCode, style: const TextStyle(color: AppColors.muted)),
          ],
        ),
      ],
    );
  }
}
