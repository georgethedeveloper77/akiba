import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../core/widgets/kit.dart';
import '../../data/models/insurance_type.dart';
import '../../data/models/insurer.dart';
import '../../data/snapshot_providers.dart';
import 'insure_common.dart';
import 'insure_motor_page.dart';
import 'insure_travel_page.dart';

/// Insurance home. Full page pushed from the Markets spotlight (class name kept
/// as InsureOverlay so the existing entry in markets_page is unchanged). The
/// type grid is admin-driven ([insuranceTypesProvider]); Motor and Travel open
/// their comparison flows, other types show a coming-soon state.
class InsureOverlay extends ConsumerWidget {
  const InsureOverlay({super.key});

  String? _liveSub(String key, List<Insurer> insurers) {
    if (key == 'motor') {
      final motor = insurers.where((i) => i.hasMotor).toList();
      if (motor.isEmpty) return null;
      num? from;
      double? minRate;
      for (final i in motor) {
        final p = i.minPremium;
        if (p != null && (from == null || p < from)) from = p;
        final r = i.motorRate;
        if (r != null && (minRate == null || r < minRate)) minRate = r;
      }
      return t('insure.motorGrid', {
        'n': '${motor.length}',
        'rate': minRate == null ? '' : minRate.toStringAsFixed(2),
      });
    }
    if (key == 'travel') {
      num? from;
      for (final i in insurers) {
        final f = i.travelFrom;
        if (f != null && (from == null || f < from)) from = f;
      }
      return from == null ? null : t('insure.travelGrid', {'amt': kes(from)});
    }
    return null;
  }

  bool _hasData(String key, List<Insurer> insurers) => switch (key) {
        'motor' => insurers.any((i) => i.hasMotor),
        'travel' => insurers.any((i) => i.hasTravel),
        _ => true, // non-flow types are presentation-only cards
      };

  void _openType(BuildContext context, InsuranceType type) {
    if (type.isLive && type.key == 'motor') {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const InsureMotorPage()));
    } else if (type.isLive && type.key == 'travel') {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const InsureTravelPage()));
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(t('insure.comingSoon', {'type': type.label})),
        ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final insurers = ref.watch(insurersProvider);
    final types = ref.watch(insuranceTypesProvider);

    // A type card is a flow only when live AND it has data; otherwise it reads
    // as coming-soon (honest, no empty flow).
    final n = insurers.where((i) => i.hasMotor || i.hasTravel).length;

    return Scaffold(
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
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          DisplayHeader(
            title: t('insure.title'),
            sub: n > 0
                ? '${t('insure.homeSub')} \u00b7 ${t('insure.insurersLive', {'n': '$n'})}'
                : t('insure.homeSub'),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 11,
              crossAxisSpacing: 11,
              childAspectRatio: 1.55,
              children: [
                for (final type in types)
                  _TypeCell(
                    type: type,
                    live: type.isLive && _hasData(type.key, insurers),
                    sub: (type.isLive ? _liveSub(type.key, insurers) : null) ??
                        type.sub ??
                        t('insure.soon'),
                    onTap: () => _openType(context, type),
                  ),
              ],
            ),
          ),
          Disclaimer(t('insure.disc.home')),
          InsureH2(t('insure.why.title'), small: t('insure.why.sub')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _WhyRow(t('insure.why.1'), tint: c.accent),
                _WhyRow(t('insure.why.2'), tint: c.up),
                _WhyRow(t('insure.why.3'), tint: c.accent),
                _WhyRow(t('insure.why.4'), tint: c.up, last: true),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(t('insure.privacyNote'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: c.faint,
                    fontSize: 9.5,
                    fontFamily: fructaFonts.mono)),
          ),
        ],
      ),
    );
  }
}

/// A type grid card. Wraps [InsTypeCard] and overlays a SOON badge for
/// non-flow / dataless types.
class _TypeCell extends StatelessWidget {
  const _TypeCell({
    required this.type,
    required this.live,
    required this.sub,
    required this.onTap,
  });

  final InsuranceType type;
  final bool live;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final card = InsTypeCard(
      icon: insureTypeIcon(type.icon),
      label: type.label,
      sub: sub,
      onTap: onTap,
    );
    if (live) return card;
    return Stack(
      children: [
        Opacity(opacity: 0.72, child: card),
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: c.s3,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(t('insure.soonBadge'),
                style: TextStyle(
                    color: c.faint,
                    fontSize: 8,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                    fontFamily: fructaFonts.mono)),
          ),
        ),
      ],
    );
  }
}

class _WhyRow extends StatelessWidget {
  const _WhyRow(this.text, {required this.tint, this.last = false});
  final String text;
  final Color tint;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: tint, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 9),
          Expanded(
            child:
                Text(text, style: TextStyle(color: c.muted, fontSize: 12.5)),
          ),
          Icon(Icons.check_rounded, size: 16, color: c.up),
        ],
      ),
    );
  }
}
