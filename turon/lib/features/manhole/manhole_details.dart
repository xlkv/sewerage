import 'package:flutter/material.dart';
import '../../shared/widgets/details_parts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../core/geo_utils.dart';
import '../../core/theme.dart';
import '../../data/models/manhole.dart';
import '../../data/models/master.dart';
import '../../data/models/pipe.dart';
import '../../data/repositories/manhole_repo.dart';
import '../../shared/widgets/confirm_dialog.dart';

class ManholeDetails extends ConsumerStatefulWidget {
  final Manhole manhole;
  final Map<String, Manhole> allManholes;
  final Map<String, Pipe> allPipes;
  final List<Master> masters;
  final bool isAdmin;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final VoidCallback onMove;
  final void Function(String pipeId) onSelectPipe;
  final VoidCallback onDeleted;
  final ScrollController? scrollController;

  const ManholeDetails({
    super.key,
    required this.manhole,
    required this.allManholes,
    required this.allPipes,
    required this.masters,
    required this.isAdmin,
    required this.onClose,
    required this.onEdit,
    required this.onMove,
    required this.onSelectPipe,
    required this.onDeleted,
    this.scrollController,
  });

  @override
  ConsumerState<ManholeDetails> createState() => _ManholeDetailsState();
}

class _ManholeDetailsState extends ConsumerState<ManholeDetails> {
  bool _deleting = false;

  Future<void> _handleDelete() async {
    final hasConnectedPipes = widget.allPipes.values.any(
      (p) =>
          p.fromManholeId == widget.manhole.id ||
          p.toManholeId == widget.manhole.id,
    );
    if (hasConnectedPipes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Avval bu kolodetsga ulangan quvurlarni o\'chiring'),
        ),
      );
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: 'Kolodetsni o\'chirish',
      message:
          'Haqiqatan ham "${widget.manhole.code}" kolodetsini o\'chirmoqchimisiz?',
    );
    if (!confirmed || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(manholeRepoProvider).delete(widget.manhole.id);
      if (!mounted) return;
      widget.onDeleted();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapErrorToMessage(e))),
      );
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.manhole;
    final master = widget.masters
        .where((item) => item.id == m.masterId)
        .firstOrNull;

    final outgoingPipes = widget.allPipes.values
        .where((p) => p.fromManholeId == m.id)
        .toList();
    final incomingPipes = widget.allPipes.values
        .where((p) => p.toManholeId == m.id)
        .toList();

    return ListView(
      controller: widget.scrollController,
      shrinkWrap: widget.scrollController == null,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        DetailsHeader(
          kind: 'Kolodets',
          code: m.code,
          status: m.status,
          icon: Icons.radio_button_checked_rounded,
          onClose: widget.onClose,
        ),
        const SizedBox(height: 16),
        MetricGrid(
          metrics: [
            MetricData(
              icon: Icons.height_rounded,
              label: 'Chuqurligi',
              value: m.heightM != null
                  ? '${m.heightM!.toStringAsFixed(2)} m'
                  : '—',
            ),
            MetricData(
              icon: Icons.circle_outlined,
              label: 'Diametr',
              value: m.diameterM != null
                  ? '${m.diameterM!.toStringAsFixed(2)} m'
                  : '—',
            ),
            MetricData(
              icon: Icons.engineering_outlined,
              label: 'Usta',
              value: master?.fullName ?? '—',
            ),
            MetricData(
              icon: Icons.place_outlined,
              label: 'Koordinata',
              value:
                  '${m.lat.toStringAsFixed(5)}\n${m.lng.toStringAsFixed(5)}',
            ),
          ],
        ),
        if (master?.phone != null && master!.phone!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Usta telefoni: ${master.phone}',
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
        if (m.note != null && m.note!.trim().isNotEmpty) ...[
          const SectionTitle('Izoh'),
          Text(m.note!),
        ],
        if (outgoingPipes.isNotEmpty || incomingPipes.isNotEmpty) ...[
          SectionTitle(
            'Ulangan quvurlar (${outgoingPipes.length + incomingPipes.length})',
          ),
          ...outgoingPipes.map((p) {
            final toCode = widget.allManholes[p.toManholeId]?.code ?? '?';
            return _ConnectedPipeTile(
              pipe: p,
              directionLabel: '${m.code} \u2192 $toCode (chiquvchi)',
              onTap: () => widget.onSelectPipe(p.id),
            );
          }),
          ...incomingPipes.map((p) {
            final fromCode = widget.allManholes[p.fromManholeId]?.code ?? '?';
            return _ConnectedPipeTile(
              pipe: p,
              directionLabel: '$fromCode \u2192 ${m.code} (kiruvchi)',
              onTap: () => widget.onSelectPipe(p.id),
            );
          }),
        ],
        if (widget.isAdmin) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _deleting ? null : widget.onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Tahrirlash'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _deleting ? null : widget.onMove,
                  icon: const Icon(Icons.open_with_rounded, size: 18),
                  label: const Text('Surish'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            children: [
              TextButton.icon(
                onPressed: _deleting ? null : _handleDelete,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                ),
                icon: _deleting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline, size: 18),
                label: const Text('O\'chirish'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ConnectedPipeTile extends StatelessWidget {
  final Pipe pipe;
  final String directionLabel;
  final VoidCallback onTap;

  const _ConnectedPipeTile({
    required this.pipe,
    required this.directionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        dense: true,
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        leading: Icon(
          Icons.timeline_rounded,
          color: AppColors.forStatus(pipe.status),
        ),
        title: Text('${pipe.code} • ${formatLength(pipe.effectiveLengthM)}'),
        subtitle: Text(directionLabel),
        trailing: const Icon(Icons.chevron_right, size: 18),
      ),
    );
  }
}
