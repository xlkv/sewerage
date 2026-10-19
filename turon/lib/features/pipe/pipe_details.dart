import 'package:flutter/material.dart';
import '../../data/models/work_status.dart';
import '../../core/theme.dart';
import '../../shared/widgets/details_parts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../core/geo_utils.dart';
import '../../data/models/manhole.dart';
import '../../data/models/pipe.dart';
import '../../data/repositories/pipe_repo.dart';
import '../../shared/widgets/confirm_dialog.dart';

class PipeDetails extends ConsumerStatefulWidget {
  final Pipe pipe;
  final Map<String, Manhole> allManholes;
  final bool isAdmin;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final void Function(String manholeId) onSelectManhole;
  final VoidCallback onDeleted;
  final ScrollController? scrollController;

  const PipeDetails({
    super.key,
    required this.pipe,
    required this.allManholes,
    required this.isAdmin,
    required this.onClose,
    required this.onEdit,
    required this.onSelectManhole,
    required this.onDeleted,
    this.scrollController,
  });

  @override
  ConsumerState<PipeDetails> createState() => _PipeDetailsState();
}

class _PipeDetailsState extends ConsumerState<PipeDetails> {
  bool _busy = false;

  Future<void> _handleSwapDirection() async {
    setState(() => _busy = true);
    try {
      await ref.read(pipeRepoProvider).update(
        widget.pipe.id,
        fromManholeId: widget.pipe.toManholeId,
        toManholeId: widget.pipe.fromManholeId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quvur yo\'nalishi almashtirildi')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapErrorToMessage(e))),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _handleRevertToAutoLength() async {
    setState(() => _busy = true);
    try {
      await ref.read(pipeRepoProvider).update(
        widget.pipe.id,
        clearManualLength: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avto uzunlikka qaytarildi')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapErrorToMessage(e))),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Quvurni o\'chirish',
      message:
          'Haqiqatan ham "${widget.pipe.code}" quvurini o\'chirmoqchimisiz?',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(pipeRepoProvider).delete(widget.pipe.id);
      if (!mounted) return;
      widget.onDeleted();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapErrorToMessage(e))),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _changeStatus(WorkStatus status) async {
    try {
      await ref.read(pipeRepoProvider).update(widget.pipe.id, status: status);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapErrorToMessage(e))),
      );
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pipe;
    final fromManhole = widget.allManholes[p.fromManholeId];
    final toManhole = widget.allManholes[p.toManholeId];

    return ListView(
      controller: widget.scrollController,
      shrinkWrap: widget.scrollController == null,
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      children: [
        DetailsHeader(
          kind: 'Quvur',
          code: p.code,
          status: p.status,
          icon: Icons.timeline_rounded,
          onClose: widget.onClose,
          onStatusChange: widget.isAdmin ? _changeStatus : null,
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  final box = context.findRenderObject() as RenderBox?;
                  final half = (box?.size.width ?? 0) / 2;
                  final target = details.localPosition.dx < half
                      ? fromManhole
                      : toManhole;
                  if (target != null) widget.onSelectManhole(target.id);
                },
                child: FlowDiagram(
                  from: fromManhole?.code ?? '?',
                  to: toManhole?.code ?? '?',
                  color: AppColors.forStatus(p.status),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        MetricGrid(
          metrics: [
            MetricData(
              icon: Icons.straighten_rounded,
              label: 'Uzunlik',
              value: formatLength(p.effectiveLengthM),
              badge: p.isManual ? 'QO\'LDA' : 'AVTO',
            ),
            MetricData(
              icon: Icons.circle_outlined,
              label: 'Diametr',
              value: '${p.diameterMm} mm',
            ),
          ],
        ),
        if (p.isManual)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'GPS bo\'yicha: ${formatLength(p.lengthAutoM)}',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ),
                if (widget.isAdmin)
                  TextButton.icon(
                    onPressed: _busy ? null : _handleRevertToAutoLength,
                    icon: const Icon(Icons.restore_rounded, size: 16),
                    label: const Text('Avtoga qaytarish'),
                  ),
              ],
            ),
          ),
        if (p.note != null && p.note!.trim().isNotEmpty) ...[
          const SectionTitle('Izoh'),
          Text(p.note!),
        ],
        if (widget.isAdmin) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : widget.onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Tahrirlash'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _busy ? null : _handleSwapDirection,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text('Yo\'nalish'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            children: [
              TextButton.icon(
                onPressed: _busy ? null : _handleDelete,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                ),
                icon: _busy
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


