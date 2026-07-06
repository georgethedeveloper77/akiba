import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../data/models/fund.dart';

/// "Performance" — trailing annualised returns (YTD/1Y/3Y/5Y) as paired
/// fund-vs-benchmark bars on one shared scale, plus the best/worst monthly
/// band as a consistency signal. Same data the manager's fact sheet publishes
/// (0027) — this is a dataless reskin of the old table, so nothing new is read.
///
/// Hidden when nothing is seeded (fund.hasReturns == false), so it never shows
/// an empty or fabricated chart. Icon-free — mono figures and drawn legend
/// swatches (never glyphs), matched to the peer-compare bars on the same page.
class FundPerformance extends StatelessWidget {
  const FundPerformance(this.fund, {super.key, this.tint});

  final Fund fund;
  final Color? tint;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String? _asOf() {
    final iso = fund.returnsAsOf;
    final d = iso == null ? null : DateTime.tryParse(iso);
    return d == null ? null : '${_months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final brand = tint ?? c.accent;

    // (label, fund, benchmark). YTD has no stored benchmark → null.
    final rows = <(String, double?, double?)>[
      if (fund.returnYtd != null) ('YTD', fund.returnYtd, null),
      if (fund.return1y != null) ('1 YEAR', fund.return1y, fund.bench1y),
      if (fund.return3y != null) ('3 YEAR', fund.return3y, fund.bench3y),
      if (fund.return5y != null) ('5 YEAR', fund.return5y, fund.bench5y),
    ];
    final hasBand = fund.bestMonth != null && fund.worstMonth != null;
    if (rows.isEmpty && !hasBand) return const SizedBox.shrink();

    // One scale across every fund + benchmark magnitude on the card, so bar
    // lengths are comparable row to row. Abs keeps a negative period in frame.
    var maxV = 0.0;
    for (final r in rows) {
      if (r.$2 != null) maxV = math.max(maxV, r.$2!.abs());
      if (r.$3 != null) maxV = math.max(maxV, r.$3!.abs());
    }
    if (maxV <= 0) maxV = 1;

    final hasBench = rows.any((r) => r.$3 != null);
    final asOf = _asOf();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
          child: Text(
            asOf != null
                ? 'PERFORMANCE \u00b7 AS OF ${asOf.toUpperCase()}'
                : 'PERFORMANCE',
            style: TextStyle(
                color: c.faint,
                fontFamily: AkibaFonts.mono,
                fontSize: 10.5,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w600),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: c.s1,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rows.isNotEmpty) ...[
                  if (hasBench) _Legend(brand: brand),
                  for (var i = 0; i < rows.length; i++)
                    _PerfBars(
                      label: rows[i].$1,
                      fund: rows[i].$2,
                      bench: rows[i].$3,
                      maxV: maxV,
                      brand: brand,
                      divider: i < rows.length - 1,
                    ),
                ],
                if (hasBand) ...[
                  if (rows.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1, color: c.line),
                    ),
                  _MonthBand(
                    worst: fund.worstMonth!,
                    best: fund.bestMonth!,
                    tint: brand,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Drawn swatch + label legend (no glyph dots). Fund in brand, benchmark in the
/// same muted fill the benchmark bars use.
class _Legend extends StatelessWidget {
  const _Legend({required this.brand});
  final Color brand;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget item(Color col, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  color: col, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: c.muted,
                    fontFamily: AkibaFonts.mono,
                    fontSize: 10)),
          ],
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          item(brand, 'Fund'),
          const SizedBox(width: 16),
          item(c.s3, 'Benchmark'),
        ],
      ),
    );
  }
}

/// One period: label + fund-vs-bench delta header, then a fund bar and (when
/// present) a benchmark bar on the card's shared scale.
class _PerfBars extends StatelessWidget {
  const _PerfBars({
    required this.label,
    required this.fund,
    required this.bench,
    required this.maxV,
    required this.brand,
    required this.divider,
  });
  final String label;
  final double? fund;
  final double? bench;
  final double maxV;
  final Color brand;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final delta = (fund != null && bench != null) ? fund! - bench! : null;

    return Container(
      decoration: divider
          ? BoxDecoration(border: Border(bottom: BorderSide(color: c.line)))
          : null,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: TextStyle(
                      color: c.muted,
                      fontFamily: AkibaFonts.mono,
                      fontSize: 11,
                      letterSpacing: 0.4)),
              const Spacer(),
              if (delta != null)
                Text(
                  '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(2)} pts vs bench',
                  style: TextStyle(
                      color: c.delta(delta),
                      fontFamily: AkibaFonts.mono,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()]),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (fund != null)
            _MiniBar(
              name: 'FUND',
              value: fund!,
              frac: (fund!.abs() / maxV).clamp(0.0, 1.0),
              fill: fund! >= 0 ? brand : c.down,
              valueColor: fund! >= 0 ? brand : c.down,
              bold: true,
            ),
          if (bench != null) ...[
            const SizedBox(height: 7),
            _MiniBar(
              name: 'BENCH',
              value: bench!,
              frac: (bench!.abs() / maxV).clamp(0.0, 1.0),
              fill: bench! >= 0 ? c.s3 : c.down,
              valueColor: bench! >= 0 ? c.muted : c.down,
              bold: false,
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({
    required this.name,
    required this.value,
    required this.frac,
    required this.fill,
    required this.valueColor,
    required this.bold,
  });
  final String name;
  final double value;
  final double frac;
  final Color fill;
  final Color valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(name,
              style: TextStyle(
                  color: c.faint,
                  fontFamily: AkibaFonts.mono,
                  fontSize: 9,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: c.s2),
                  FractionallySizedBox(
                    widthFactor: frac,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      builder: (_, t, child) =>
                          FractionallySizedBox(widthFactor: t, child: child),
                      child: DecoratedBox(decoration: BoxDecoration(color: fill)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 58,
          child: Text(
            '${value.toStringAsFixed(2)}%',
            textAlign: TextAlign.right,
            style: TextStyle(
                color: valueColor,
                fontFamily: AkibaFonts.mono,
                fontSize: 12.5,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
      ],
    );
  }
}

class _MonthBand extends StatelessWidget {
  const _MonthBand(
      {required this.worst, required this.best, required this.tint});
  final double worst;
  final double best;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MONTHLY RETURN RANGE \u00b7 TRAILING 12 MO',
            style: TextStyle(
                color: c.faint,
                fontFamily: AkibaFonts.mono,
                fontSize: 9,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(
          children: [
            _end(context, 'WORST', worst, c.muted, alignEnd: false),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: LinearGradient(colors: [c.s3, tint]),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _end(context, 'BEST', best, c.text, alignEnd: true),
          ],
        ),
      ],
    );
  }

  Widget _end(BuildContext context, String k, double v, Color valColor,
      {required bool alignEnd}) {
    final c = context.c;
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(k,
            style: TextStyle(
                color: c.faint,
                fontFamily: AkibaFonts.mono,
                fontSize: 8.5,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text('${v.toStringAsFixed(2)}%',
            style: TextStyle(
                color: valColor,
                fontFamily: AkibaFonts.mono,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}
