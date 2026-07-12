import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../core/widgets/kit.dart';
import '../../data/models/insurance_type.dart';
import '../../data/models/insurer.dart';
import '../../data/models/remote_config.dart';
import '../../data/snapshot_providers.dart';
import 'insure_common.dart';
import 'insure_motion.dart';
import 'insure_motor_page.dart';
import 'insure_travel_page.dart';
import 'insurer_directory_page.dart';

/// Insurance home, V9.
///
/// The old page led with "Compare cover in minutes, not weeks", a promise about
/// us that a reader has no way to check. This one leads with the SPREAD: the
/// ratio between the cheapest and the dearest comprehensive quote for one
/// identical car. That is a fact about the market, it is the most persuasive
/// thing our data knows, and it is computed from the same tariffs the quote
/// screen prices with, so the hero can never advertise a gap the app then fails
/// to show.
///
/// Structure: the hook, then the two things you can do about it, then the
/// evidence that justifies both. The disclaimer sits at the foot, where a
/// disclaimer belongs, instead of interrupting the page before anything has
/// been offered.
///
/// Apple 2.1: a category appears ONLY when a live flow with real data sits
/// behind it. Nothing here is a teaser.
class InsureOverlay extends ConsumerWidget {
  const InsureOverlay({super.key});

  /// A mid-market Kenyan saloon. Used only to make the spread concrete; every
  /// real quote reprices against the user's own value.
  static const double refValue = 3450000;

  bool _runnable(InsuranceType type, List<Insurer> insurers) {
    if (!type.isLive) return false;
    return switch (type.key) {
      'motor' => insurers.any((i) => i.hasMotor),
      'travel' => insurers.any((i) => i.hasTravel),
      _ => false,
    };
  }

  /// Live comprehensive premiums on the reference car, cheapest first.
  ///
  /// quote() returns null, never zero, for an insurer that does not write the
  /// class. Null means "we do not know what they charge", so that insurer is
  /// excluded from the spread rather than ranked cheapest, which would be the
  /// worst possible bug on a page whose whole argument is about price.
  static List<({Insurer insurer, double premium})> _quotes(
    List<Insurer> insurers,
  ) {
    final out = <({Insurer insurer, double premium})>[];
    for (final i in insurers) {
      final q = i.quote(
        refValue,
        cls: MotorClass.private,
        cover: CoverType.comprehensive,
      );
      if (q != null && q > 0) {
        out.add((insurer: i, premium: landedPremium(q)));
      }
    }
    out.sort((a, b) => a.premium.compareTo(b.premium));
    return out;
  }

  void _openType(BuildContext context, InsuranceType type) {
    final Widget? page = switch (type.key) {
      'motor' => const InsureMotorPage(),
      'travel' => const InsureTravelPage(),
      _ => null,
    };
    if (page == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final rc = ref.watch(remoteConfigProvider);
    final insurers = ref.watch(insurersProvider);
    final types = ref
        .watch(insuranceTypesProvider)
        .where((t) => _runnable(t, insurers))
        .toList();

    if (insurers.isEmpty) {
      return _shell(context, [
        DisplayHeader(title: t('insure.title')),
        Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            t('insure.emptyHome'),
            textAlign: TextAlign.center,
            style: TextStyle(color: c.muted),
          ),
        ),
      ]);
    }

    final quotes = _quotes(insurers);
    final flagged = insurers.where((i) => !i.canWriteNewBusiness).length;

    // The primary action is the first live category. The code does not hardcode
    // Motor, so when a cover ships with more behind it, it takes the top slot
    // on its own.
    final primary = types.isEmpty ? null : types.first;
    final secondary =
        types.length > 1 ? types.sublist(1) : const <InsuranceType>[];

    return _shell(context, [
      _SpreadHero(quotes: quotes, insurers: insurers),
      if (primary != null)
        Stagger(
          index: 0,
          child: _PrimaryCard(
            type: primary,
            insurers: insurers,
            quotes: quotes,
            onTap: () => _openType(context, primary),
          ),
        ),
      for (var k = 0; k < secondary.length; k++)
        Stagger(
          index: k + 1,
          child: _SecondaryCard(
            icon: insureTypeIcon(secondary[k].key),
            title: secondary[k].label,
            sub: secondary[k].sub ?? '',
            onTap: () => _openType(context, secondary[k]),
          ),
        ),
      Stagger(
        index: secondary.length + 1,
        child: _DirectoryCard(
          insurers: insurers,
          flagged: flagged,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const InsurerDirectoryPage()),
          ),
        ),
      ),
      if (quotes.length >= 2) ...[
        _SectionHead(
          title: t('insure.proof.title'),
          small: t('insure.proof.sub'),
        ),
        _SpreadChart(quotes: quotes),
      ],
      _CombinedRatioChart(rc: rc),
      _Foot(text: rcText(rc, 'insure.disc.home')),
    ]);
  }

  Widget _shell(BuildContext context, List<Widget> children) {
    final c = context.c;
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
        padding: const EdgeInsets.only(bottom: 10),
        children: children,
      ),
    );
  }
}

// ── hero ──────────────────────────────────────────────────────────────────
/// The spread, rendered as the largest thing on the page.
///
/// Falls back to a plain licensed count when fewer than two insurers publish a
/// rate. It never falls back to a slogan: if we cannot prove a gap, we do not
/// claim one.
class _SpreadHero extends StatelessWidget {
  const _SpreadHero({required this.quotes, required this.insurers});

  final List<({Insurer insurer, double premium})> quotes;
  final List<Insurer> insurers;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final has = quotes.length >= 2;
    final multiple = has ? quotes.last.premium / quotes.first.premium : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: c.up,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                has
                    ? t('insure.hero.kicker', {'n': '${quotes.length}'})
                    : t('insure.hero.kickerNone'),
                style: TextStyle(
                  color: c.accent,
                  fontSize: 10,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (has)
            _GradientNumber('${multiple!.toStringAsFixed(1)}x')
          else
            Text(
              '${insurers.length}',
              style: TextStyle(
                color: c.text,
                fontFamily: fructaFonts.mono,
                fontSize: 58,
                height: 0.95,
                fontWeight: FontWeight.w800,
                letterSpacing: -3,
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: 280,
            child: Text.rich(
              TextSpan(
                style: TextStyle(color: c.muted, fontSize: 13, height: 1.55),
                children: has
                    ? [
                        TextSpan(text: t('insure.hero.leadA')),
                        TextSpan(
                          text: t('insure.hero.leadB'),
                          style: TextStyle(
                            color: c.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(text: t('insure.hero.leadC')),
                      ]
                    : [TextSpan(text: t('insure.hero.leadNone'))],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The spread figure, washed accent into text. A ShaderMask, not a hardcoded
/// gradient: both stops are theme tokens, so it survives a light/dark flip and
/// an accent change.
class _GradientNumber extends StatelessWidget {
  const _GradientNumber(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ShaderMask(
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [c.accent, c.text],
      ).createShader(rect),
      blendMode: BlendMode.srcIn,
      child: Text(
        text,
        style: TextStyle(
          // Replaced by the shader, but must be opaque for srcIn to bite.
          color: c.text,
          fontFamily: fructaFonts.mono,
          fontSize: 62,
          height: 0.95,
          fontWeight: FontWeight.w800,
          letterSpacing: -3.2,
        ),
      ),
    );
  }
}

// ── primary action ────────────────────────────────────────────────────────
/// The one thing we most want tapped, styled like it, and carrying a live
/// preview of the quotes behind it so the spread is visible BEFORE the tap.
///
/// A row that looks like a list item does not get tapped. A card that shows you
/// what is inside it does.
class _PrimaryCard extends StatelessWidget {
  const _PrimaryCard({
    required this.type,
    required this.insurers,
    required this.quotes,
    required this.onTap,
  });

  final InsuranceType type;
  final List<Insurer> insurers;
  final List<({Insurer insurer, double premium})> quotes;
  final VoidCallback onTap;

  String _sub() {
    if (type.key != 'motor') return type.sub ?? '';
    final motor = insurers.where((i) => i.hasMotor).length;
    double? minRate;
    for (final i in insurers) {
      final r = i.motorRate;
      if (r != null && (minRate == null || r < minRate)) minRate = r;
    }
    return minRate == null
        ? t('insure.card.nInsurers', {'n': '$motor'})
        : t('insure.card.motorSub', {
            'n': '$motor',
            'rate': minRate.toStringAsFixed(2),
          });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [c.accentSoft, c.accent.withValues(alpha: 0)],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: c.accent),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.accent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      insureTypeIcon(type.key),
                      color: c.inkOn(c.accent),
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type.label,
                          style: TextStyle(
                            color: c.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _sub(),
                          style: TextStyle(color: c.muted, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward,
                      size: 17,
                      color: c.inkOn(c.accent),
                    ),
                  ),
                ],
              ),
              if (quotes.length >= 2) ...[
                const SizedBox(height: 16),
                _MiniSpread(quotes: quotes),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The live quotes as columns, cheapest gold and dearest red, rising from the
/// baseline on entry.
class _MiniSpread extends StatelessWidget {
  const _MiniSpread({required this.quotes});
  final List<({Insurer insurer, double premium})> quotes;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final dearest = quotes.last.premium;
    final last = quotes.length - 1;

    return Column(
      children: [
        SizedBox(
          height: 46,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var k = 0; k < quotes.length; k++) ...[
                if (k > 0) const SizedBox(width: 5),
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: quotes[k].premium / dearest),
                    duration: Duration(milliseconds: 700 + k * 70),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: v.clamp(0.02, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: k == 0
                                ? c.accent
                                : k == last
                                    ? c.down
                                    : c.line2,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              kes(quotes.first.premium),
              style: TextStyle(
                color: c.accent,
                fontFamily: fructaFonts.mono,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              kes(dearest),
              style: TextStyle(
                color: c.down,
                fontFamily: fructaFonts.mono,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── secondary cards ───────────────────────────────────────────────────────
class _SecondaryCard extends StatelessWidget {
  const _SecondaryCard({
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
    this.trailing,
    this.child,
  });

  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;
  final Widget? trailing;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 11, 20, 0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.s1,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.line),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.s3,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 20, color: c.muted),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: c.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (trailing != null) ...[
                          const SizedBox(width: 7),
                          trailing!,
                        ],
                      ],
                    ),
                    if (sub.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        sub,
                        style: TextStyle(color: c.faint, fontSize: 11),
                      ),
                    ],
                    if (child != null) ...[
                      const SizedBox(height: 10),
                      child!,
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, size: 18, color: c.faint),
            ],
          ),
        ),
      ),
    );
  }
}

/// The register card. The FLAGGED count is the hook: nothing else in Kenya
/// tells a retail buyer which insurer the regulator seized.
class _DirectoryCard extends StatelessWidget {
  const _DirectoryCard({
    required this.insurers,
    required this.flagged,
    required this.onTap,
  });

  final List<Insurer> insurers;
  final int flagged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return _SecondaryCard(
      icon: Icons.verified_outlined,
      title: t('insure.dir.title'),
      sub: t('insure.dir.entry', {'n': '${insurers.length}'}),
      onTap: onTap,
      trailing: flagged == 0
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: c.downSoft,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                t('insure.dir.flaggedN', {'n': '$flagged'}),
                style: TextStyle(
                  color: c.down,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
      child: _LogoWall(insurers: insurers),
    );
  }
}

/// Overlapping marks, capped with a "+N". Ringed in the panel colour so the
/// discs read as separate discs without a dark halo.
class _LogoWall extends StatelessWidget {
  const _LogoWall({required this.insurers});
  final List<Insurer> insurers;

  static const double _size = 26;
  static const double _step = 19;
  static const int _cap = 4;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    // Lead with the ones we can price: they are the ones with real marks, and a
    // wall of monograms says nothing.
    final ranked = [...insurers]..sort((a, b) {
      final pa = (a.hasMotor || a.hasTravel) ? 0 : 1;
      final pb = (b.hasMotor || b.hasTravel) ? 0 : 1;
      return pa.compareTo(pb);
    });
    final shown = ranked.take(_cap).toList();
    final extra = insurers.length - shown.length;
    final slots = shown.length + (extra > 0 ? 1 : 0);

    return SizedBox(
      height: _size,
      width: _size + _step * (slots - 1),
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

// ── evidence ──────────────────────────────────────────────────────────────
class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.title, required this.small});
  final String title;
  final String small;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            title,
            style: TextStyle(
              color: c.text,
              fontSize: 21,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              small,
              style: TextStyle(color: c.faint, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpreadChart extends StatelessWidget {
  const _SpreadChart({required this.quotes});
  final List<({Insurer insurer, double premium})> quotes;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final dearest = quotes.last.premium;
    final cheapest = quotes.first.premium;
    final last = quotes.length - 1;

    return Stagger(
      index: 0,
      child: BarChart(
        title: t('insure.proof.chartTitle'),
        subtitle: t('insure.proof.chartSub', {
          'value': kesCompact(InsureOverlay.refValue),
        }),
        bars: [
          for (var k = 0; k < quotes.length; k++)
            BarDatum(
              label: shortInsurerName(quotes[k].insurer.name),
              value: quotes[k].premium / dearest,
              display: kesCompact(quotes[k].premium),
              color: k == 0
                  ? c.accent
                  : k == last
                      ? c.down
                      : c.line2,
              highlight: k == 0 || k == last,
            ),
        ],
        foot: t('insure.proof.chartFoot', {
          'gap': kesCompact(dearest - cheapest),
          'cheap': shortInsurerName(quotes.first.insurer.name),
          'dear': shortInsurerName(quotes.last.insurer.name),
        }),
      ),
    );
  }
}

/// Combined ratio by class, from remote config.
///
/// This is the only chart on the page that cannot come from insurer rows, and
/// it is worth being explicit about why. Kenya publishes NO per-insurer
/// combined ratio, only these class-wide IRA figures. So the honest ceiling of
/// what we can say about underwriting profitability is "the motor book loses
/// money", never "this insurer's book loses money".
///
/// An unset key renders no bar. All four unset, and the section vanishes.
class _CombinedRatioChart extends StatelessWidget {
  const _CombinedRatioChart({required this.rc});
  final RemoteConfig rc;

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    final rows = <({String label, double value})>[
      (
        label: t('insure.cr.motorCommercial'),
        value: rc.number('insure.cr.motor_commercial', 0),
      ),
      (
        label: t('insure.cr.motorPrivate'),
        value: rc.number('insure.cr.motor_private', 0),
      ),
      (label: t('insure.cr.medical'), value: rc.number('insure.cr.medical', 0)),
      (label: t('insure.cr.marine'), value: rc.number('insure.cr.marine', 0)),
    ].where((r) => r.value > 0).toList();

    if (rows.isEmpty) return const SizedBox.shrink();

    final worst = rows.map((r) => r.value).reduce((a, b) => a > b ? a : b);

    return Stagger(
      index: 1,
      child: BarChart(
        title: t('insure.cr.title'),
        subtitle: t('insure.cr.sub'),
        labelWidth: 88,
        bars: [
          for (final r in rows)
            BarDatum(
              label: r.label,
              value: r.value / worst,
              display: r.value.toStringAsFixed(0),
              // Above 100 the class pays out more than it takes in. The colour
              // carries that threshold, so a reader who skips the footnote
              // still gets the point.
              color: r.value >= 110
                  ? c.down
                  : r.value >= 100
                      ? c.accent
                      : c.up,
              highlight: r.value >= 110,
            ),
        ],
        foot: t('insure.cr.foot'),
      ),
    );
  }
}

class _Foot extends StatelessWidget {
  const _Foot({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.only(top: 26),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 34),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Text(
        '$text ${t('insure.privacyNote')}',
        style: TextStyle(color: c.faint, fontSize: 10, height: 1.7),
      ),
    );
  }
}
