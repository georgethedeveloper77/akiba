import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../core/widgets/kit.dart';
import '../../data/models/insurer.dart';
import '../../data/snapshot_providers.dart';
import 'insure_common.dart';
import 'insurer_detail_page.dart';

enum MotorSort { cheapest, claims, benefits, value }

class InsureMotorPage extends ConsumerStatefulWidget {
  const InsureMotorPage({super.key});

  @override
  ConsumerState<InsureMotorPage> createState() => _InsureMotorPageState();
}

class _InsureMotorPageState extends ConsumerState<InsureMotorPage> {
  double _value = 3450000;
  MotorSort _sort = MotorSort.cheapest;

  List<Insurer> _sorted(List<Insurer> motor) {
    final list = [...motor];
    int claims(Insurer i) => i.claimsDays ?? 1 << 30;
    switch (_sort) {
      case MotorSort.cheapest:
        list.sort((a, b) => a.premium(_value).compareTo(b.premium(_value)));
      case MotorSort.claims:
        list.sort((a, b) => claims(a).compareTo(claims(b)));
      case MotorSort.benefits:
        list.sort((a, b) => b.benefits.length.compareTo(a.benefits.length));
      case MotorSort.value:
        double score(Insurer i) =>
            i.premium(_value) / (i.benefits.length + (i.rating ?? 0) + 1);
        list.sort((a, b) => score(a).compareTo(score(b)));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final motor =
        ref.watch(insurersProvider).where((i) => i.hasMotor).toList();

    if (motor.isEmpty) {
      return _shell(
        c,
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(t('insure.emptyMotor'),
                textAlign: TextAlign.center,
                style: TextStyle(color: c.muted)),
          ),
        ),
      );
    }

    final sorted = _sorted(motor);
    final best = sorted.first;

    // Cheapest / priciest for the GAP line.
    final byPrice = [...sorted]
      ..sort((a, b) => a.premium(_value).compareTo(b.premium(_value)));
    final cheap = byPrice.first;
    final exp = byPrice.last;
    final gap = exp.premium(_value) - cheap.premium(_value);

    return _shell(
      c,
      ListView(
        padding: const EdgeInsets.only(bottom: 36),
        children: [
          DisplayHeader(title: t('insure.motor'), sub: t('insure.motorSub')),
          _ValueCard(
              value: _value, onChanged: (v) => setState(() => _value = v)),
          _FilterPills(sort: _sort, onSort: (s) => setState(() => _sort = s)),
          const SizedBox(height: 4),
          for (final i in sorted)
            InsureQuoteRow(
              name: i.name,
              logoDomain: i.logoDomain,
              brand: insurerBrand(context, i),
              stars: i.rating,
              meta: i.claimsDays == null
                  ? null
                  : t('insure.claimsDays', {'d': '${i.claimsDays}'}),
              benefits: i.benefits,
              priceText: kes(i.premium(_value)),
              subText: i.excessLabel.isEmpty
                  ? null
                  : t('insure.excessShort', {'v': i.excessLabel}),
              best: i.id == best.id,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => InsurerDetailPage.motor(i, value: _value),
              )),
            ),
          InsureH2(t('insure.whyPriciest')),
          if (gap > 0)
            SignalRow(
              tag: t('insure.gapTag'),
              tone: SignalTone.neutral,
              text: t('insure.gap', {
                'name': exp.name,
                'amt': kes(gap),
                'cheap': cheap.name,
              }),
              showDivider: exp.signals.isNotEmpty,
            ),
          for (var s = 0; s < exp.signals.length; s++)
            SignalRow(
              tag: exp.signals[s].label,
              text: exp.signals[s].text,
              tone: _tone(exp.signals[s].tag),
              showDivider: s < exp.signals.length - 1,
            ),
          InsureFoot(t('insure.motorFoot')),
          Disclaimer(t('insure.disc.motor')),
        ],
      ),
    );
  }

  Widget _shell(fructaColors c, Widget body) => Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.bg,
          surfaceTintColor: Colors.transparent,
          foregroundColor: c.text,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: body,
      );
}

SignalTone _tone(String tag) => switch (tag.toUpperCase()) {
      'STRENGTH' => SignalTone.positive,
      'WATCH' => SignalTone.negative,
      _ => SignalTone.neutral,
    };

class _ValueCard extends StatelessWidget {
  const _ValueCard({required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      decoration: BoxDecoration(
        color: c.s1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('insure.yourCar'),
              style: TextStyle(
                  color: c.faint,
                  fontSize: 9,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t('insure.vehicleValue'),
                  style: TextStyle(color: c.muted, fontSize: 13)),
              Text(kes(value),
                  style: TextStyle(
                    color: c.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
            ],
          ),
          Slider(
            value: value,
            min: 500000,
            max: 10000000,
            divisions: 190,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _FilterPills extends StatelessWidget {
  const _FilterPills({required this.sort, required this.onSort});
  final MotorSort sort;
  final ValueChanged<MotorSort> onSort;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget pill(MotorSort s, String label) {
      final on = s == sort;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => onSort(s),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
            decoration: BoxDecoration(
              color: on ? c.text : c.s1,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: on ? c.text : c.line),
            ),
            child: Text(label,
                style: TextStyle(
                    color: on ? c.bg : c.muted,
                    fontSize: 13,
                    fontWeight: on ? FontWeight.w600 : FontWeight.w500)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 8, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          pill(MotorSort.cheapest, t('insure.filter.cheapest')),
          pill(MotorSort.claims, t('insure.filter.claims')),
          pill(MotorSort.benefits, t('insure.filter.benefits')),
          pill(MotorSort.value, t('insure.filter.value')),
        ]),
      ),
    );
  }
}
