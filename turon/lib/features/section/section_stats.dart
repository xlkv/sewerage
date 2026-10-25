import '../../data/models/pipe.dart';

/// Auto figures of a section: total length, counts, length per diameter.
class SectionStats {
  final double lengthM;
  final int pipeCount;
  final int manholeCount;

  /// Diameter (mm) -> (metres, pipe count), largest diameter first.
  final List<({int diameterMm, double meters, int count})> byDiameter;

  const SectionStats({
    required this.lengthM,
    required this.pipeCount,
    required this.manholeCount,
    required this.byDiameter,
  });

  factory SectionStats.of({
    required Iterable<String> pipeIds,
    required int manholeCount,
    required Map<String, Pipe> allPipes,
  }) {
    var length = 0.0;
    var count = 0;
    final byD = <int, ({double meters, int count})>{};
    for (final id in pipeIds) {
      final p = allPipes[id];
      if (p == null) continue;
      count++;
      length += p.lengthM;
      final prev = byD[p.diameterMm] ?? (meters: 0.0, count: 0);
      byD[p.diameterMm] = (
        meters: prev.meters + p.lengthM,
        count: prev.count + 1,
      );
    }
    final keys = byD.keys.toList()..sort((a, b) => b - a);
    return SectionStats(
      lengthM: length,
      pipeCount: count,
      manholeCount: manholeCount,
      byDiameter: [
        for (final d in keys)
          (diameterMm: d, meters: byD[d]!.meters, count: byD[d]!.count),
      ],
    );
  }

  /// Manholes of a section: ends of its pipes plus explicitly picked ones.
  static Set<String> manholesOf(
    Iterable<String> pipeIds,
    Map<String, Pipe> allPipes, {
    Iterable<String> extra = const [],
  }) => {
    for (final id in pipeIds)
      if (allPipes[id] case final p?) ...[p.fromManholeId, p.toManholeId],
    ...extra,
  };
}
