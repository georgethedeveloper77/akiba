import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../data/models/insurer.dart';
import '../../../data/snapshot_providers.dart';
import '../../insure/insure_common.dart';

/// Insurance spotlight on Markets, rebuilt to the house card pattern.
///
/// It previously used its own shape (transparent fill, line2 border, radius 20,
/// eyebrow inside the card) while every other Markets card uses an external
/// mono eyebrow above an s1 panel with a line border at radius 18. That is why
/// it read as though it came from a different app. It now matches
/// MarketAllocationDonut and MarketContextCard exactly.
///
/// The headline is the SPREAD, not a slogan. "Compare motor and travel cover"
/// asks the user to take our word for it; "the same car costs 2.3x more at one
/// insurer than another" hands them the reason and lets them check it. The
/// figure is computed from the same tariffs the quote screen prices with, so
/// the card can never promise a spread the app does not then show.
class InsuranceSpotlight extends ConsumerWidget {
  const InsuranceSpotlight({super.key, required this.onTap});

  final VoidCallback onTap;

  /// A mid-market saloon. Only ever used to make the spread concrete; the real
  /// quote screen reprices against the user's own value.
  static const double _refValue = 3450000;

  static String _compact(num v) {
    final d = v.toDouble();
    if (d >= 1e6) {
      final m = d / 1e6;
      return '${m >= 10 ? m.round() : m.toStringAsFixed(1)}M';
    }
    if (d >= 1000) return '${(d / 1000).round()}k';
    return d.round().toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final insurers = ref.watch(insurersProvider);
    if (insurers.isEmpty) return const SizedBox.shrink();

    final flow = insurers.where((i) => i.hasMotor || i.hasTravel).toList();

    // Live comprehensive quotes on one reference car. quote() returns null,
    // never zero, for an insurer that does not write the class, so an unknown
    // price is excluded rather than ranked cheapest.
    final premiums = <double>[];
    for (final i in insurers) {
      final q = i.quote(
        _refValue,
        cls: MotorClass.private,
        cover: CoverType.comprehensive,
      );
      if (q != null && q > 0) premiums.add(landedPremium(q));
    }
    premiums.sort();

    final hasSpread = premiums.length >= 2;
    final cheapest = hasSpread ? premiums.first : null;
    final dearest = hasSpread ? premiums.last : null;
    final multiple = hasSpread ? dearest! / cheapest! : null;

    // Headline: the spread when we can prove one, otherwise the plainest true
    // statement we can make. Never a slogan.
    final headline = hasSpread
        ? 'The same car, ${multiple!.toStringAsFixed(1)}x apart'
        : 'Compare cover from ${flow.length} insurers';

    final sub = hasSpread
        ? 'KES ${_compact(cheapest!)} to KES ${_compact(dearest!)} '
              'for identical comprehensive cover'
        : 'Published rates only, never an estimate';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // External eyebrow, matching MARKET BY AUM and MARKET CONTEXT.
          Row(
            children: [
              Text(
                'INSURANCE',
                style: TextStyle(
                  color: c.faint,
                  fontFamily: fructaFonts.mono,
                  fontSize: 10.5,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'IRA \u00b7 ${insurers.length} licensed',
                style: TextStyle(
                  color: c.faint,
                  fontFamily: fructaFonts.mono,
                  fontSize: 10.5,
                ),
              ),
              const Spacer(),
              Text(
                'Compare',
                style: TextStyle(
                  color: c.accentInk,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: c.accentInk),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(16),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: c.s1,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: c.line),
              ),
              child: Stack(
                children: [
                  // Ambient accent wash, kept inside the panel now that the
                  // panel actually has a fill to sit on.
                  Positioned(
                    left: -90,
                    top: -70,
                    bottom: -70,
                    child: IgnorePointer(
                      child: Container(
                        width: 210,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              c.accent.withValues(alpha: 0.10),
                              c.accent.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.accentSoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.shield_outlined, color: c.accent),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              headline,
                              style: TextStyle(
                                color: c.text,
                                fontSize: 14.5,
                                height: 1.25,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              sub,
                              style: TextStyle(
                                color: c.muted,
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                            if (flow.length >= 3) ...[
                              const SizedBox(height: 11),
                              _AvatarStack(insurers: flow),
                            ],
                          ],
                        ),
                      ),
                    ],
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

/// Overlapping insurer logos, capped with a "+N" bubble. Ringed in the PANEL
/// colour (s1), not the page colour, now that the card has a fill: ringing in
/// c.bg on an s1 card drew a visible dark halo around every disc.
class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.insurers});
  final List<Insurer> insurers;

  static const double _size = 24;
  static const double _step = 16;
  static const int _cap = 5;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final shown = insurers.take(_cap).toList();
    final extra = insurers.length - shown.length;
    final slots = shown.length + (extra > 0 ? 1 : 0);
    final width = _size + _step * (slots - 1);

    return SizedBox(
      height: _size,
      width: width,
      child: Stack(
        children: [
          for (var k = 0; k < shown.length; k++)
            Positioned(
              left: _step * k,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: c.s1, width: 1.5),
                ),
                // InsurerLogo, not FundLogo: it resolves the hosted company
                // logo before falling back to the domain, which the old call
                // never did. That is why every insurer here rendered as a
                // monogram even when a real mark was uploaded.
                child: InsurerLogo(shown[k], size: _size),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: _step * shown.length,
              child: Container(
                width: _size,
                height: _size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.s3,
                  border: Border.all(color: c.s1, width: 1.5),
                ),
                child: Text(
                  '+$extra',
                  style: TextStyle(
                    color: c.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
