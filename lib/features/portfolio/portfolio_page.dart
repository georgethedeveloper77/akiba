import 'package:akiba/data/snapshot_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/main_scaffold.dart';
import '../../core/categories.dart';
import '../../core/category_colors.dart';
import '../../core/format.dart';
import '../../core/settings_prefs.dart';
import '../../core/theme.dart';
import '../../core/widgets/kit.dart';
import '../../data/models/fund.dart';
import '../../data/models/holding.dart';
import '../../data/providers.dart';
import '../../engine/accrual_engine.dart';
import 'add_holding_page.dart';
import 'manage_holding_sheet.dart';
import 'projection_card.dart';

/// v5 `.pg-portfolio` — markets-first portfolio, consolidated in KES.
/// Hide-balances is the persisted settings pref (V5 handoff): the eye here
/// and the Settings toggle drive the same value.
class PortfolioPage extends ConsumerWidget {
  const PortfolioPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holdings = ref.watch(holdingsProvider);
    final byId = ref.watch(fundsByIdProvider);
    final fx = ref.watch(usdKesProvider); // KES per USD
    final hidden = ref.watch(
      settingsControllerProvider.select((p) => p.hideBalances),
    );
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: holdings.isEmpty
            ? const _Empty()
            : _Full(holdings: holdings, byId: byId, fx: fx, hidden: hidden),
      ),
    );
  }
}

// ── Topbar: ＋ Add · eye · avatar ───────────────────────────────────────────
class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final hidden = ref.watch(
      settingsControllerProvider.select((p) => p.hideBalances),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const AddHoldingPage())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
              decoration: BoxDecoration(
                color: c.s1,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.line2),
              ),
              child: Text(
                '\uFF0B Add',
                style: TextStyle(
                  color: c.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => ref
                .read(settingsControllerProvider.notifier)
                .setHideBalances(!hidden),
            icon: Icon(
              hidden
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: c.muted,
            ),
          ),
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c.accent, c.accent.withValues(alpha: 0.7)],
              ),
            ),
            child: Text(
              'G',
              style: TextStyle(
                color: c.onAccent,
                fontFamily: AkibaFonts.mono,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Full extends StatelessWidget {
  const _Full({
    required this.holdings,
    required this.byId,
    required this.fx,
    required this.hidden,
  });

  final List<Holding> holdings;
  final Map<String, Fund> byId;
  final double? fx;
  final bool hidden;

  double _kes(Holding h) =>
      h.currency == 'USD' ? h.balance * (fx ?? 0) : h.balance;

  double _dailyNet(Fund f, double balance) => f.taxFree
      ? AccrualEngine.dailyInterest(balance, f.currentRate ?? 0)
      : AccrualEngine.dailyInterestNet(balance, f.currentRate ?? 0);

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    var totalKes = 0.0;
    var dailyKes = 0.0;
    var usdTotal = 0.0;
    final byCategory = <String, double>{};
    var wSum = 0.0, w = 0.0;

    for (final h in holdings) {
      final kes = _kes(h);
      totalKes += kes;
      if (h.currency == 'USD') usdTotal += h.balance;
      final f = byId[h.fundId];
      final r = f?.currentRate;
      if (f != null && r != null) {
        // daily earning in the holding's own currency, converted to KES
        final dailyOwn = _dailyNet(f, h.balance);
        dailyKes += h.currency == 'USD' ? dailyOwn * (fx ?? 0) : dailyOwn;
        byCategory[f.category] = (byCategory[f.category] ?? 0) + kes;
        wSum += r * kes;
        w += kes;
      }
    }

    final monthlyKes = dailyKes * 365 / 12;
    final yearlyKes = dailyKes * 365;
    final pct = totalKes > 0 ? monthlyKes / totalKes * 100 : 0.0;
    final blendedGross = w > 0 ? wSum / w : 0.0;
    final providers = holdings
        .map((h) => byId[h.fundId]?.manager)
        .whereType<String>()
        .toSet()
        .length;

    String bal(String s) => hidden ? '\u2022\u2022\u2022\u2022' : s;

    final allocTotal = byCategory.values.fold<double>(0, (a, b) => a + b);
    final slices =
        (byCategory.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .map(
              (e) => AllocSlice(
                label: categoryLabel(e.key),
                color: categoryColor(e.key),
                weight: e.value,
                valueText: allocTotal > 0
                    ? '${(e.value / allocTotal * 100).round()}%'
                    : '0%',
              ),
            )
            .toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        const _TopBar(),
        DisplayHeader(
          title: 'Portfolio',
          sub:
              '${holdings.length} holdings \u00b7 $providers providers \u00b7 consolidated in KES',
        ),

        // pf-big — count-up total (mono 44)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: hidden
              ? _bigText(context, 'KES \u2022\u2022\u2022\u2022')
              : TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: totalKes),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => _bigText(context, money('KES', v)),
                ),
        ),

        // pf-dl — monthly net earning (consolidated), incl. USD @ FX note
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Text.rich(
            TextSpan(
              style: const TextStyle(
                fontFamily: AkibaFonts.mono,
                fontSize: 12.5,
              ),
              children: [
                TextSpan(
                  text: '\u25b2 ${bal(money('KES', monthlyKes.round()))} ',
                  style: TextStyle(color: c.up),
                ),
                TextSpan(
                  text:
                      '(${pct.toStringAsFixed(1)}%) this month${usdTotal > 0 && fx != null ? ' \u00b7 incl. \$${withCommas(usdTotal)} @ ${fx!.toStringAsFixed(2)}' : ''}',
                  style: TextStyle(
                    color: c.muted,
                    fontFamily: AkibaFonts.sans,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),

        // pf-chart (110px) — hidden: no portfolio-valuation series exists yet.
        // Wire a real value series here and it renders (see notes).
        EarnStrip([
          EarnCell('Earning / day', '+${money('KES', dailyKes.round())}'),
          EarnCell('/ month', '+${money('KES', monthlyKes.round())}'),
          EarnCell('/ year', '+${money('KES', yearlyKes.round())}'),
        ]),

        if (slices.isNotEmpty) ...[
          const SectionHeader(title: 'Allocation'),
          AllocationBar(slices),
          Legend(slices),
        ],

        const SectionHeader(title: 'Holdings', trailing: 'net earnings shown'),
        for (final h in holdings)
          _HoldingRow(holding: h, fund: byId[h.fundId], fx: fx, hidden: hidden),
        _AddRow(
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AddHoldingPage())),
        ),

        if (totalKes > 0 && blendedGross > 0) ...[
          const SectionHeader(title: 'If you keep investing'),
          ProjectionCard(
            principal: totalKes,
            grossRate: blendedGross,
            currency: 'KES',
          ),
        ],

        Disclaimer(
          "USD positions earn their own USD yields, converted at today's CBK "
          'indicative rate for the total. Projection compounds your blended net '
          'yield monthly \u2014 not a promise.',
        ),
      ],
    );
  }

  Widget _bigText(BuildContext context, String s) => Text(
    s,
    style: TextStyle(
      color: context.c.text,
      fontFamily: AkibaFonts.mono,
      fontSize: 44,
      fontWeight: FontWeight.w600,
      letterSpacing: -2,
      height: 1,
    ),
  );
}

// ── Holding tile (v5 .tile) ────────────────────────────────────────────────
class _HoldingRow extends StatelessWidget {
  const _HoldingRow({
    required this.holding,
    required this.fund,
    required this.fx,
    required this.hidden,
  });

  final Holding holding;
  final Fund? fund;
  final double? fx;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final f = fund;
    final name = f?.name ?? holding.fundId;
    final rate = f?.currentRate;
    final ccy = holding.currency;

    String? earn;
    if (f != null && rate != null) {
      final daily = f.taxFree
          ? AccrualEngine.dailyInterest(holding.balance, rate)
          : AccrualEngine.dailyInterestNet(holding.balance, rate);
      if (ccy == 'USD') {
        final kes = fx != null
            ? ' \u00b7 \u2248${money('KES', (daily * fx!).round())}'
            : '';
        earn = '+\$${daily.toStringAsFixed(2)}/day$kes';
      } else {
        earn = '+${money('KES', daily.round())}/day';
      }
    }

    final sub = rate != null
        ? '${rate.toStringAsFixed(2)}% ${f!.taxFree ? 'tax-free' : 'gross'}${ccy == 'USD' ? ' \u00b7 USD' : ''}'
        : 'rate unavailable';
    final balText = hidden
        ? '\u2022\u2022\u2022\u2022'
        : (ccy == 'USD'
              ? '\$${withCommas(holding.balance)}'
              : money('KES', holding.balance));

    return InkWell(
      onTap: () => showManageHolding(context, holding, f),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            FundLogo(domain: f?.logoDomain, seed: f?.manager ?? name, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: c.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(sub, style: TextStyle(color: c.faint, fontSize: 10.5)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  balText,
                  style: TextStyle(
                    color: c.text,
                    fontFamily: AkibaFonts.mono,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (earn != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    earn,
                    style: TextStyle(
                      color: c.up,
                      fontFamily: AkibaFonts.mono,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dashed add-holding row (v5 .addrow) ─────────────────────────────────────
class _AddRow extends StatelessWidget {
  const _AddRow({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GestureDetector(
        onTap: onTap,
        child: DottedBorderBox(
          color: c.line2,
          radius: 16,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Text(
                '\uFF0B Add a holding',
                style: TextStyle(
                  color: c.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded dashed border box (Flutter has no built-in dashed border).
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({
    super.key,
    required this.child,
    required this.color,
    this.radius = 16,
  });
  final Widget child;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _DashPainter(color, radius), child: child);
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color, this.radius);
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final dashed = Path();
    const dash = 5.0, gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        dashed.addPath(metric.extractPath(d, d + dash), Offset.zero);
        d += dash + gap;
      }
    }
    canvas.drawPath(
      dashed,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_DashPainter old) =>
      old.color != color || old.radius != radius;
}

// ── Empty state ─────────────────────────────────────────────────────────────
class _Empty extends ConsumerWidget {
  const _Empty();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 60, 32, 20),
      children: [
        Center(
          child: Container(
            width: 74,
            height: 74,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.accentSoft,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(Icons.work_outline, color: c.accent, size: 34),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Your portfolio is empty',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: c.text,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Add what you already hold and Akiba shows your real balance, daily '
          'earnings and projections \u2014 all in one place.',
          textAlign: TextAlign.center,
          style: TextStyle(color: c.muted, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 24),
        CtaFull(
          label: 'Add your first investment',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AddHoldingPage())),
        ),
        CtaGhost(
          label: 'Browse top rates',
          onTap: () => ref.read(selectedTabProvider.notifier).state = 0,
        ),
      ],
    );
  }
}
