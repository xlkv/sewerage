import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/geo_utils.dart';
import '../../core/theme.dart';
import '../../data/models/manhole.dart';
import '../../data/models/pipe.dart';
import '../../data/models/work_status.dart';
import 'feature_providers.dart';
import 'map_controller.dart';
import 'map_mode.dart';
import 'map_objects_layer.dart';
import 'network_graph.dart';

BoxDecoration _cardDecoration() => BoxDecoration(
  color: AppColors.surface,
  borderRadius: BorderRadius.circular(AppRadii.card),
  boxShadow: AppShadows.floating,
);

// ───────────────────────── Flow trace legend ─────────────────────────

class TraceLegendCard extends StatelessWidget {
  final Manhole origin;
  final FlowTrace trace;
  final Map<String, Pipe> pipes;
  final Map<String, Manhole> manholes;
  final VoidCallback onClose;

  const TraceLegendCard({
    super.key,
    required this.origin,
    required this.trace,
    required this.pipes,
    required this.manholes,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    // Outfalls: downstream manholes with no outgoing pipe.
    final outfalls = trace.downstreamManholes
        .where((id) => !pipes.values.any((p) => p.fromManholeId == id))
        .map((id) => manholes[id]?.code)
        .whereType<String>()
        .toList();

    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.water_rounded, color: AppColors.brand, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Oqim izi · ${origin.code}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Yopish',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),
          _TraceRow(
            color: MapObjectsLayer.traceDownColor,
            title: 'Pastga oqadi',
            pipes: trace.downstreamPipes.length,
            meters: NetworkGraph.lengthOf(trace.downstreamPipes, pipes),
            trailing: outfalls.isEmpty ? null : '→ ${outfalls.join(', ')}',
          ),
          const SizedBox(height: 6),
          _TraceRow(
            color: MapObjectsLayer.traceUpColor,
            title: 'Yuqoridan quyiladi',
            pipes: trace.upstreamPipes.length,
            meters: NetworkGraph.lengthOf(trace.upstreamPipes, pipes),
          ),
          if (trace.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Bu kolodetsga hali quvur ulanmagan',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _TraceRow extends StatelessWidget {
  final Color color;
  final String title;
  final int pipes;
  final double meters;
  final String? trailing;

  const _TraceRow({
    required this.color,
    required this.title,
    required this.pipes,
    required this.meters,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          pipes == 0
              ? '—'
              : '$pipes quvur · ${GeoUtils.formatLength(meters)}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Text(trailing!, style: const TextStyle(color: AppColors.muted)),
        ],
        const SizedBox(width: 8),
      ],
    );
  }
}

// ───────────────────────── Timeline panel ─────────────────────────

class TimelinePanel extends ConsumerWidget {
  final TimelineState timeline;
  final double completedMeters;
  final double totalMeters;

  const TimelinePanel({
    super.key,
    required this.timeline,
    required this.completedMeters,
    required this.totalMeters,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(timelineProvider.notifier);
    final date = DateFormat('d-MMMM, yyyy', 'uz').format(timeline.at);
    final pct = totalMeters <= 0 ? 0.0 : completedMeters / totalMeters;

    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.history_rounded,
                color: AppColors.brand,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Qurilish taymlayni',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Yopish',
                onPressed: notifier.close,
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  date,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              Text(
                '${GeoUtils.formatLength(completedMeters)} tugallangan · '
                '${(pct * 100).round()}%',
                style: const TextStyle(
                  color: AppColors.completed,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          Row(
            children: [
              IconButton.filled(
                tooltip: timeline.playing ? 'To\'xtatish' : 'Ijro etish',
                onPressed: () => notifier.setPlaying(!timeline.playing),
                icon: Icon(
                  timeline.playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                ),
              ),
              Expanded(
                child: Slider(
                  value: timeline.progress.clamp(0, 1),
                  onChanged: (v) {
                    notifier.setPlaying(false);
                    notifier.seek(v);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Rubber band ─────────────────────────

class RubberBandInfo {
  final double meters;
  final String? snappedId;
  final String? snappedCode;

  const RubberBandInfo({
    required this.meters,
    this.snappedId,
    this.snappedCode,
  });
}

/// Crosshair in the map centre + length pill; when the line snaps to a
/// manhole the pill turns into a "connect" button.
class RubberBandOverlay extends StatelessWidget {
  final ValueNotifier<RubberBandInfo?> info;
  final void Function(String manholeId) onConnect;

  const RubberBandOverlay({
    super.key,
    required this.info,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RubberBandInfo?>(
      valueListenable: info,
      builder: (context, value, _) {
        if (value == null) return const SizedBox.shrink();
        final snapped = value.snappedId != null;
        return IgnorePointer(
          ignoring: !snapped,
          child: Stack(
            children: [
              Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: snapped ? 34 : 22,
                  height: snapped ? 34 : 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: snapped ? AppColors.brand : AppColors.ink,
                      width: 2.5,
                    ),
                    color: snapped
                        ? AppColors.brand.withValues(alpha: 0.15)
                        : Colors.transparent,
                  ),
                ),
              ),
              Align(
                alignment: const Alignment(0, 0.18),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: snapped
                      ? FilledButton.icon(
                          key: const ValueKey('connect'),
                          onPressed: () => onConnect(value.snappedId!),
                          icon: const Icon(Icons.link_rounded, size: 18),
                          label: Text(
                            '${value.snappedCode} ga ulash · '
                            '${GeoUtils.formatLength(value.meters)}',
                          ),
                        )
                      : Container(
                          key: const ValueKey('len'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.ink,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '≈ ${GeoUtils.formatLength(value.meters)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ───────────────────────── Map style sheet ─────────────────────────

class MapStyleSheet extends ConsumerWidget {
  const MapStyleSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layer = ref.watch(mapLayerProvider);
    final appearance = ref.watch(mapAppearanceProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Xarita ko\'rinishi',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 14),
            SegmentedButton<MapLayer>(
              segments: const [
                ButtonSegment(
                  value: MapLayer.scheme,
                  icon: Icon(Icons.map_outlined),
                  label: Text('Sxema'),
                ),
                ButtonSegment(
                  value: MapLayer.satellite,
                  icon: Icon(Icons.satellite_alt_outlined),
                  label: Text('Sputnik'),
                ),
              ],
              selected: {layer},
              onSelectionChanged: (s) =>
                  ref.read(mapLayerProvider.notifier).setLayer(s.first),
            ),
            const SizedBox(height: 16),
            for (final a in MapAppearance.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AppearanceTile(
                  appearance: a,
                  selected: a == appearance,
                  onTap: () => ref.read(mapAppearanceProvider.notifier).set(a),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AppearanceTile extends StatelessWidget {
  final MapAppearance appearance;
  final bool selected;
  final VoidCallback onTap;

  const _AppearanceTile({
    required this.appearance,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color line) = switch (appearance) {
      MapAppearance.blueprint => (const Color(0xFFF1F5F9), AppColors.brand),
      MapAppearance.sun => (const Color(0xFFFFFBEB), AppColors.inProgress),
      MapAppearance.night => (const Color(0xFF1E293B), const Color(0xFF5EEAD4)),
    };
    return Material(
      color: selected ? AppColors.brandSoft : AppColors.bg,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(
              color: selected ? AppColors.brand : AppColors.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 40,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: CustomPaint(painter: _MiniNetworkPainter(line)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appearance.label,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      appearance.description,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedOpacity(
                opacity: selected ? 1 : 0,
                duration: const Duration(milliseconds: 160),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.brand,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniNetworkPainter extends CustomPainter {
  final Color color;

  const _MiniNetworkPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final a = Offset(size.width * 0.18, size.height * 0.35);
    final b = Offset(size.width * 0.55, size.height * 0.35);
    final c = Offset(size.width * 0.55, size.height * 0.75);
    final d = Offset(size.width * 0.85, size.height * 0.75);
    canvas.drawLine(a, b, p);
    canvas.drawLine(b, c, p);
    canvas.drawLine(c, d, p);
    for (final o in [a, b, c, d]) {
      canvas.drawCircle(o, 4, Paint()..color = Colors.white);
      canvas.drawCircle(o, 3, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniNetworkPainter old) => old.color != color;
}

// ───────────────────────── Search ─────────────────────────

class SearchResult {
  final Selection selection;
  final String code;
  final String subtitle;
  final WorkStatus status;
  final bool isPipe;

  const SearchResult({
    required this.selection,
    required this.code,
    required this.subtitle,
    required this.status,
    required this.isPipe,
  });
}

/// Matches codes case-insensitively; a bare number ("12") matches K-12 and
/// Q-12. Exact code matches come first.
List<SearchResult> searchNetwork(
  String query,
  Map<String, Manhole> manholes,
  Map<String, Pipe> pipes,
) {
  final q = query.trim().toLowerCase().replaceAll(' ', '');
  if (q.isEmpty) return const [];
  bool matches(String code) => code.toLowerCase().replaceAll(' ', '').contains(q);
  int score(String code) {
    final c = code.toLowerCase();
    if (c == q || c.endsWith('-$q')) return 0;
    if (c.startsWith(q)) return 1;
    return 2;
  }

  final results = <SearchResult>[
    for (final m in manholes.values)
      if (matches(m.code))
        SearchResult(
          selection: ManholeSelection(m.id),
          code: m.code,
          subtitle: 'Kolodets · ${m.status.label}',
          status: m.status,
          isPipe: false,
        ),
    for (final p in pipes.values)
      if (matches(p.code))
        SearchResult(
          selection: PipeSelection(p.id),
          code: p.code,
          subtitle:
              'Quvur · ${manholes[p.fromManholeId]?.code ?? '?'} → '
              '${manholes[p.toManholeId]?.code ?? '?'} · '
              '${GeoUtils.formatLength(p.lengthM)}',
          status: p.status,
          isPipe: true,
        ),
  ];
  results.sort((a, b) {
    final s = score(a.code).compareTo(score(b.code));
    return s != 0 ? s : a.code.length.compareTo(b.code.length);
  });
  return results.take(30).toList();
}

class SearchSheet extends StatefulWidget {
  final Map<String, Manhole> manholes;
  final Map<String, Pipe> pipes;
  final void Function(Selection selection) onSelect;

  const SearchSheet({
    super.key,
    required this.manholes,
    required this.pipes,
    required this.onSelect,
  });

  @override
  State<SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<SearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final results = searchNetwork(_query, widget.manholes, widget.pipes);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Kod bo\'yicha qidirish: K-12, Q-3 yoki 12',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (v) => setState(() => _query = v),
                onSubmitted: (_) {
                  if (results.isNotEmpty) widget.onSelect(results.first.selection);
                },
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                ),
                child: _query.trim().isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Kolodets yoki quvur kodini yozing — xarita o\'sha '
                          'joyga uchib boradi.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    : results.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Hech narsa topilmadi',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: results.length,
                        itemBuilder: (context, i) {
                          final r = results[i];
                          final color = AppColors.forStatus(r.status);
                          return ListTile(
                            onTap: () => widget.onSelect(r.selection),
                            leading: CircleAvatar(
                              backgroundColor: color.withValues(alpha: 0.14),
                              child: Icon(
                                r.isPipe
                                    ? Icons.timeline_rounded
                                    : Icons.radio_button_checked_rounded,
                                color: color,
                              ),
                            ),
                            title: Text(
                              r.code,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(r.subtitle),
                            trailing: const Icon(Icons.north_east_rounded),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
