import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/models/insurer.dart';
import '../../data/snapshot_providers.dart';
import 'insure_common.dart';
import 'insure_motion.dart';

/// The trust surface, built ONLY from sourced public data:
///
///   license status   IRA register / public notices under s.67C
///   financial rating GCR national scale
///   market share     IRA quarterly industry release, Table 16
///   combined ratio   AKI annual market report
///   complaints       IRA quarterly industry release
///
/// Every cell hides when its datum is unseeded and the whole panel hides when
/// nothing is seeded, so the screen degrades to honest silence rather than
/// filling space with invented numbers.
///
/// Two absences are deliberate and permanent until the data exists. There is no
/// published per-insurer claims-settlement rate in Kenya, so we never show one.
/// And per-insurer combined ratio and complaint counts are published nowhere
/// either: the IRA prints them class-wide and industry-wide only. Those cells
/// therefore render for nobody today, and that is correct. A null is a fact.
class InsurerTrustPanel extends ConsumerWidget {
  const InsurerTrustPanel(this.insurer, {super.key});
  final Insurer insurer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i = insurer;
    if (!i.hasTrustData) return const SizedBox.shrink();

    final peers = ref.watch(insurersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!i.canWriteNewBusiness) _StatusBanner(insurer: i),
        InsureH2(t('insure.trust.title'), small: t('insure.trust.sub')),
        if (i.financialRating != null) _RatingCard(insurer: i),
        _MarketShareChart(insurer: i, peers: peers),
        _OtherCells(insurer: i),
        _Timeline(insurer: i),
        if (i.iraClassCodes.isNotEmpty) _ClassCodes(codes: i.iraClassCodes),
        if (i.dataSource != null) InsureFoot(i.dataSource!),
      ],
    );
  }
}

/// A hard regulatory warning. An insurer under statutory management cannot
/// write new business, so the app warns instead of quietly comparing it.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.insurer});
  final Insurer insurer;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final closed = insurer.licenseStatus == 'closed';
    final title = closed
        ? t('insure.trust.closed')
        : t('insure.trust.statMgmt');
    final body = closed
        ? t('insure.trust.closedBody')
        : t('insure.trust.statMgmtBody');

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.downSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.down.withValues(alpha: 0.34)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.down,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.priority_high_rounded,
              size: 19,
              color: c.inkOn(c.down),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: c.down,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: TextStyle(color: c.muted, fontSize: 12, height: 1.55),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The rating, as a chart rather than a string.
///
/// "AA+(KE)" is meaningless to a retail buyer who has never seen a GCR grade.
/// The arc and the seven-rung ladder put it on a scale, so the reader gets
/// "near the top" without knowing what the letters mean. An unmappable grade
/// renders the letters alone rather than a guessed position on the ladder.
class _RatingCard extends StatelessWidget {
  const _RatingCard({required this.insurer});
  final Insurer insurer;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final i = insurer;
    final grade = i.financialRating!;
    final rung = GradeScale.rungFor(grade);

    final meta = [
      if (i.ratingAgency != null) i.ratingAgency!,
      if (i.ratingOutlook != null) i.ratingOutlook!,
    ].join(' \u00b7 ');

    // Strip the "(KE)" suffix for the arc centre: it is the same on every
    // national-scale grade and it does not fit.
    final short = grade.toUpperCase().replaceAll('(KE)', '').trim();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.s1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          RingGauge(
            fraction: rung == null ? 0 : rung / 7,
            color: c.up,
            size: 84,
            stroke: 7,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  short,
                  style: TextStyle(
                    color: c.up,
                    fontFamily: fructaFonts.mono,
                    fontSize: short.length > 3 ? 15 : 18,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  t('insure.trust.grade'),
                  style: TextStyle(
                    color: c.faint,
                    fontSize: 8,
                    letterSpacing: 0.7,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('insure.trust.rating'),
                  style: TextStyle(
                    color: c.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  t('insure.trust.gradeScale'),
                  style: TextStyle(
                    color: c.muted,
                    fontSize: 11.5,
                    height: 1.55,
                  ),
                ),
                if (rung != null) ...[
                  const SizedBox(height: 10),
                  GradeScale(filled: rung, color: c.up),
                ],
                if (meta.isNotEmpty || i.ratingAsOf != null) ...[
                  const SizedBox(height: 9),
                  Text(
                    [
                      meta,
                      if (i.ratingAsOf != null) i.ratingAsOf!,
                    ].where((s) => s.isNotEmpty).join('  \u00b7  '),
                    style: TextStyle(
                      color: c.faint,
                      fontFamily: fructaFonts.mono,
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Share of gross premium income, this insurer against its named peers.
///
/// The hatched "Others" bar is the most honest element on the page. The IRA
/// names only the insurers above a reporting threshold; everyone else is folded
/// into an anonymous tail. Drawing that tail striped, and labelling it with the
/// count, says out loud that the bar is not one company and that the insurers
/// inside it are not at zero, they are simply not separately reported.
///
/// Hides entirely when fewer than two insurers carry a share.
class _MarketShareChart extends StatelessWidget {
  const _MarketShareChart({required this.insurer, required this.peers});
  final Insurer insurer;
  final List<Insurer> peers;

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    final named = peers.where((p) => p.marketSharePct != null).toList()
      ..sort((a, b) => b.marketSharePct!.compareTo(a.marketSharePct!));
    if (named.length < 2) return const SizedBox.shrink();

    final namedTotal = named.fold<double>(0, (a, p) => a + p.marketSharePct!);
    final othersCount = peers.length - named.length;
    final othersPct = 100 - namedTotal;
    final top = named.first.marketSharePct!;
    final showOthers = othersCount > 0 && othersPct > 0;
    final scale = showOthers && othersPct > top ? othersPct : top;

    return BarChart(
      title: t('insure.trust.shareTitle'),
      subtitle: t('insure.trust.shareSub', {'n': '${named.length}'}),
      labelWidth: 84,
      bars: [
        for (final p in named)
          BarDatum(
            label: shortInsurerName(p.name),
            value: p.marketSharePct! / scale,
            display: '${p.marketSharePct!.toStringAsFixed(1)}%',
            color: p.id == insurer.id ? c.accent : c.line2,
            highlight: p.id == insurer.id,
          ),
        if (showOthers)
          BarDatum(
            label: t('insure.trust.shareOthers', {'n': '$othersCount'}),
            value: othersPct / scale,
            display: '${othersPct.toStringAsFixed(1)}%',
            hatched: true,
          ),
      ],
      foot: showOthers
          ? t('insure.trust.shareFoot', {'n': '$othersCount'})
          : null,
    );
  }
}

/// Whatever else is seeded: combined ratio, complaints, licensed year. Laid out
/// two-up, and each cell present only when its datum is.
class _OtherCells extends StatelessWidget {
  const _OtherCells({required this.insurer});
  final Insurer insurer;

  @override
  Widget build(BuildContext context) {
    final i = insurer;
    final cells = <Widget>[];

    if (i.combinedRatio != null) {
      cells.add(
        _GaugeCell(
          value: i.combinedRatio!,
          good: i.combinedRatio! < 100,
          label: t('insure.trust.combined'),
          note: i.combinedRatio! < 100
              ? t('insure.trust.combinedGood')
              : t('insure.trust.combinedBad'),
          asOf: i.ratiosAsOf,
        ),
      );
    }

    if (i.complaintsCount != null) {
      cells.add(
        _StatCell(
          value: '${i.complaintsCount}',
          label: t('insure.trust.complaints'),
          note: i.complaintsResolved == null
              ? t('insure.trust.complaintsNote')
              : t('insure.trust.complaintsResolved', {
                  'n': '${i.complaintsResolved}',
                }),
          asOf: i.complaintsPeriod,
        ),
      );
    }

    if (i.licenseYear != null) {
      cells.add(
        _StatCell(
          value: '${i.licenseYear}',
          label: t('insure.trust.licensed'),
          note: t('insure.trust.licensedNote'),
        ),
      );
    }

    if (cells.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        children: [
          for (var r = 0; r < cells.length; r += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: cells[r]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: r + 1 < cells.length
                        ? cells[r + 1]
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The regulatory record as a sequence, not a single box.
///
/// Trident's collapse reads very differently as a slide (stopped filing returns
/// in 2023, absent from the 2026 register, seized in March) than it does as one
/// red rectangle. Built only from dated facts we hold; an insurer with a single
/// event gets no timeline, since a one-item sequence is just a sentence.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.insurer});
  final Insurer insurer;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final i = insurer;

    final events = <({String title, String meta, Color dot})>[
      if (!i.canWriteNewBusiness)
        (
          title: t('insure.trust.tl.statMgmt'),
          meta: i.dataSource ?? '',
          dot: c.down,
        ),
      if (i.licenseYear != null && i.canWriteNewBusiness)
        (
          title: t('insure.trust.tl.licensed'),
          meta: '${i.licenseYear}',
          dot: c.up,
        ),
      if (i.financialRating != null)
        (
          title: t('insure.trust.tl.rated', {
            'agency': i.ratingAgency ?? '',
            'grade': i.financialRating!,
            'outlook': i.ratingOutlook ?? '',
          }),
          meta: i.ratingAsOf ?? '',
          dot: c.up,
        ),
      if (i.marketSharePct != null)
        (
          title: t('insure.trust.tl.share', {
            'pct': i.marketSharePct!.toStringAsFixed(1),
          }),
          meta: i.ratiosAsOf ?? '',
          dot: c.line2,
        ),
    ];
    if (events.length < 2) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InsureH2(t('insure.trust.timeline')),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 20, 0),
          child: Column(
            children: [
              for (var k = 0; k < events.length; k++)
                Stagger(
                  index: k,
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 11,
                          child: Column(
                            children: [
                              Container(
                                width: 11,
                                height: 11,
                                margin: const EdgeInsets.only(top: 3),
                                decoration: BoxDecoration(
                                  color: events[k].dot,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: c.bg, width: 2),
                                ),
                              ),
                              if (k != events.length - 1)
                                Expanded(
                                  child: Container(width: 1, color: c.line),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              bottom: k == events.length - 1 ? 0 : 16,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  events[k].title,
                                  style: TextStyle(
                                    color: c.text,
                                    fontSize: 12,
                                    height: 1.4,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (events[k].meta.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    events[k].meta,
                                    style: TextStyle(
                                      color: c.faint,
                                      fontFamily: fructaFonts.mono,
                                      fontSize: 10,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.value,
    required this.label,
    this.note,
    this.asOf,
  });
  final String value;
  final String label;
  final String? note;
  final String? asOf;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.s1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: c.faint,
              fontSize: 9,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: c.text,
              fontFamily: fructaFonts.mono,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (note != null && note!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              note!,
              style: TextStyle(color: c.muted, fontSize: 10.5, height: 1.35),
            ),
          ],
          if (asOf != null) ...[
            const SizedBox(height: 3),
            Text(
              asOf!,
              style: TextStyle(
                color: c.faint,
                fontSize: 9,
                fontFamily: fructaFonts.mono,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Combined ratio, on a ring. Green below 100 (underwriting profit), red above
/// (paying out more than it takes in). Scaled to 130, which comfortably covers
/// every published Kenyan class figure.
class _GaugeCell extends StatelessWidget {
  const _GaugeCell({
    required this.value,
    required this.good,
    required this.label,
    required this.note,
    this.asOf,
  });
  final double value;
  final bool good;
  final String label;
  final String note;
  final String? asOf;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tint = good ? c.up : c.down;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.s1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: c.faint,
              fontSize: 9,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              RingGauge(
                fraction: (value / 130).clamp(0.0, 1.0),
                color: tint,
                size: 42,
                stroke: 4,
                child: Icon(
                  good
                      ? Icons.trending_down_rounded
                      : Icons.trending_up_rounded,
                  size: 15,
                  color: tint,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${value.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: c.text,
                  fontFamily: fructaFonts.mono,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            note,
            style: TextStyle(color: c.muted, fontSize: 10.5, height: 1.35),
          ),
          if (asOf != null) ...[
            const SizedBox(height: 3),
            Text(
              asOf!,
              style: TextStyle(
                color: c.faint,
                fontSize: 9,
                fontFamily: fructaFonts.mono,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// IRA authorised class codes, e.g. 07 Motor Private.
class _ClassCodes extends StatelessWidget {
  const _ClassCodes({required this.codes});
  final List<String> codes;

  static const _labels = <String, String>{
    '01': 'Aviation',
    '02': 'Engineering',
    '03': 'Fire Domestic',
    '04': 'Fire Industrial',
    '05': 'Liability',
    '06': 'Marine',
    '07': 'Motor Private',
    '08': 'Motor Commercial',
    '09': 'Personal Accident',
    '10': 'Theft',
    '11': 'Workmen Comp',
    '12': 'Medical',
    '13': 'Micro-insurance',
    '14': 'Miscellaneous',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final code in codes)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: c.s2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.line),
                ),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontFamily: fructaFonts.mono,
                      fontSize: 10,
                      color: c.muted,
                    ),
                    children: [
                      TextSpan(
                        text: code,
                        style: TextStyle(
                          color: c.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(text: '  ${_labels[code] ?? ''}'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
