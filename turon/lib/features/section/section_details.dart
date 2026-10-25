import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/errors.dart';
import '../../core/geo_utils.dart';
import '../../core/theme.dart';
import '../../data/models/manhole.dart';
import '../../data/models/pipe.dart';
import '../../data/models/section.dart';
import '../../data/models/work_status.dart';
import '../../data/repositories/section_repo.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/details_parts.dart';
import 'section_stats.dart';

/// Card of a section: auto figures, status/dates, note and drawings.
class SectionDetails extends ConsumerStatefulWidget {
  final Section section;
  final Set<String> pipeIds;
  final Set<String> manholeIds;
  final Map<String, Pipe> allPipes;
  final Map<String, Manhole> allManholes;
  final bool isAdmin;
  final VoidCallback onClose;
  final VoidCallback onEditPipes;
  final VoidCallback onDeleted;
  final ScrollController? scrollController;

  const SectionDetails({
    super.key,
    required this.section,
    required this.pipeIds,
    required this.manholeIds,
    required this.allPipes,
    required this.allManholes,
    required this.isAdmin,
    required this.onClose,
    required this.onEditPipes,
    required this.onDeleted,
    this.scrollController,
  });

  @override
  ConsumerState<SectionDetails> createState() => _SectionDetailsState();
}

class _SectionDetailsState extends ConsumerState<SectionDetails> {
  bool _uploading = false;
  bool _deleting = false;

  static final _dateFmt = DateFormat('d-MMMM, yyyy', 'uz');

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _changeStatus(WorkStatus status) async {
    try {
      await ref
          .read(sectionRepoProvider)
          .updateStatus(widget.section.id, status);
    } catch (e) {
      if (mounted) _snack(mapErrorToMessage(e));
      rethrow;
    }
  }

  static String _mimeOf(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.pdf')) return 'application/pdf';
    if (n.endsWith('.png')) return 'image/png';
    return 'image/jpeg';
  }

  Future<void> _addFiles() async {
    final picked = await FilePicker.pickFiles(
      dialogTitle: 'Chizma yoki hujjat (PNG, JPG, PDF)',
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (picked.isEmpty || !mounted) return;
    setState(() => _uploading = true);
    final repo = ref.read(sectionRepoProvider);
    var failed = 0;
    for (final f in picked) {
      try {
        final size = await f.length() ?? 0;
        if (size > SectionRepository.maxFileBytes) {
          if (mounted) _snack('${f.name}: 50 MB dan katta');
          failed++;
          continue;
        }
        await repo.uploadFile(
          sectionId: widget.section.id,
          name: f.name,
          bytes: await f.readAsBytes(),
          mime: _mimeOf(f.name),
        );
      } catch (e) {
        failed++;
        if (mounted) _snack('${f.name}: ${mapErrorToMessage(e)}');
      }
    }
    if (!mounted) return;
    setState(() => _uploading = false);
    if (failed == 0) {
      _snack(
        picked.length == 1
            ? 'Fayl qo\'shildi'
            : '${picked.length} ta fayl qo\'shildi',
      );
    }
  }

  Future<void> _open(SectionFile file) async {
    try {
      final url = await ref.read(sectionRepoProvider).signedUrl(file);
      if (!mounted) return;
      if (file.isPdf) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        await showDialog<void>(
          context: context,
          builder: (_) => _ImagePreview(name: file.name, url: url),
        );
      }
    } catch (e) {
      if (mounted) _snack(mapErrorToMessage(e));
    }
  }

  Future<void> _deleteFile(SectionFile file) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Faylni o\'chirish',
      message: '"${file.name}" o\'chirilsinmi?',
      isDestructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(sectionRepoProvider).deleteFile(file);
    } catch (e) {
      if (mounted) _snack(mapErrorToMessage(e));
    }
  }

  Future<void> _delete() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Uchastkani o\'chirish',
      message:
          '"${widget.section.name}" va uning fayllari o\'chirilsinmi? '
          'Quvur va kolodetslar o\'chmaydi.',
      isDestructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ref.read(sectionRepoProvider).delete(widget.section.id);
      if (mounted) widget.onDeleted();
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      _snack(mapErrorToMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.section;
    final stats = SectionStats.of(
      pipeIds: widget.pipeIds,
      manholeCount: widget.manholeIds.length,
      allPipes: widget.allPipes,
    );
    final files =
        ref.watch(sectionFilesProvider(s.id)).asData?.value ?? const [];
    final dates = [
      if (s.startDate != null) _dateFmt.format(s.startDate!),
      if (s.endDate != null) _dateFmt.format(s.endDate!),
    ];

    return ListView(
      controller: widget.scrollController,
      shrinkWrap: widget.scrollController == null,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        DetailsHeader(
          kind: 'Uchastka',
          code: s.name,
          status: s.status,
          icon: Icons.route_rounded,
          onClose: widget.onClose,
          onStatusChange: widget.isAdmin ? _changeStatus : null,
        ),
        const SizedBox(height: 16),
        MetricGrid(
          metrics: [
            MetricData(
              icon: Icons.straighten_rounded,
              label: 'Uzunligi',
              value: formatLength(stats.lengthM),
            ),
            MetricData(
              icon: Icons.timeline_rounded,
              label: 'Quvurlar',
              value: '${stats.pipeCount} ta',
            ),
            MetricData(
              icon: Icons.radio_button_checked_rounded,
              label: 'Kolodetslar',
              value: '${stats.manholeCount} ta',
            ),
            MetricData(
              icon: Icons.event_outlined,
              label: 'Muddat',
              value: dates.isEmpty ? '—' : dates.join('\n'),
            ),
          ],
        ),
        if (stats.byDiameter.isNotEmpty) ...[
          const SectionTitle('Quvur diametrlari'),
          for (final d in stats.byDiameter)
            _DiameterRow(
              diameterMm: d.diameterMm,
              meters: d.meters,
              count: d.count,
              share: stats.lengthM == 0 ? 0 : d.meters / stats.lengthM,
            ),
        ],
        if (s.note != null && s.note!.trim().isNotEmpty) ...[
          const SectionTitle('Izoh'),
          Text(s.note!),
        ],
        SectionTitle('Fayllar (${files.length})'),
        if (files.isEmpty)
          const Text(
            'Chizma yoki hujjat biriktirilmagan',
            style: TextStyle(color: AppColors.muted),
          ),
        for (final f in files)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              dense: true,
              onTap: () => _open(f),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
              leading: Icon(
                f.isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
                color: f.isPdf ? AppColors.danger : AppColors.brand,
              ),
              title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(_size(f.sizeBytes)),
              trailing: widget.isAdmin
                  ? IconButton(
                      tooltip: 'O\'chirish',
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => _deleteFile(f),
                    )
                  : const Icon(Icons.open_in_new_rounded, size: 18),
            ),
          ),
        if (widget.isAdmin) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _uploading ? null : _addFiles,
            icon: _uploading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.attach_file_rounded, size: 18),
            label: Text(_uploading ? 'Yuklanmoqda…' : 'Fayl qo\'shish'),
          ),
          const SizedBox(height: 20),
          FilledButton.tonalIcon(
            onPressed: _deleting ? null : widget.onEditPipes,
            icon: const Icon(Icons.edit_road_rounded, size: 18),
            label: const Text('Quvurlar va ma\'lumotlarni tahrirlash'),
          ),
          const SizedBox(height: 8),
          Wrap(
            children: [
              TextButton.icon(
                onPressed: _deleting ? null : _delete,
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Uchastkani o\'chirish'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  static String _size(int? bytes) {
    if (bytes == null) return '';
    if (bytes >= 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).ceil()} KB';
  }
}

class _DiameterRow extends StatelessWidget {
  final int diameterMm;
  final double meters;
  final int count;
  final double share;

  const _DiameterRow({
    required this.diameterMm,
    required this.meters,
    required this.count,
    required this.share,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Ø$diameterMm mm',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '${formatLength(meters)} · $count ta',
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 6,
              backgroundColor: AppColors.line,
              color: AppColors.brand,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final String name;
  final String url;

  const _ImagePreview({required this.name, required this.url});

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              maxScale: 8,
              child: Center(
                child: Image.network(
                  url,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : const CircularProgressIndicator(color: Colors.white),
                  errorBuilder: (context, _, _) => const Text(
                    'Rasmni ochib bo\'lmadi',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Container(
              color: Colors.black54,
              child: Row(
                children: [
                  IconButton(
                    color: Colors.white,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  IconButton(
                    color: Colors.white,
                    tooltip: 'Brauzerda ochish',
                    icon: const Icon(Icons.open_in_new_rounded),
                    onPressed: () => launchUrl(
                      Uri.parse(url),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
