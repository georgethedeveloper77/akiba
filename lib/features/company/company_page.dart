import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/categories.dart';
import '../../core/category_colors.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/insights/signal_engine.dart';
import '../../core/theme.dart';
import '../../core/widgets/kit.dart';
import '../../data/models/agent.dart';
import '../../data/models/fund.dart';
import '../../data/models/fund_composition.dart';
import '../../data/models/holding.dart';
import '../../data/providers.dart';
import '../../data/snapshot_providers.dart';
import '../../engine/accrual_engine.dart';
import '../../engine/tax.dart';
import '../alerts/alerts_page.dart';
import 'widgets/composition_pie.dart';
import 'widgets/peer_compare.dart';
import 'widgets/rate_chart.dart';

const _typeNames = {
  'mmf': 'Money Market',
  'fixed_income': 'Fixed Income',
  'equity': 'Equity',
  'balanced': 'Balanced',
  'special': 'Special',
};
String _typeName(Fund f) => _typeNames[f.fundType] ?? categoryLabel(f.category);

String _commas(num v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

String _quarter(String asOf) {
  final d = DateTime.tryParse(asOf);
  if (d == null) return asOf;
  return 'Q${((d.month - 1) ~/ 3) + 1} ${d.year}';
}

/// v6 `.co` — company/fund detail. Carded sections (chart · manager CIS ·
/// composition · peers · facts) over a brand-tinted ambient glow, matched to
/// the mockup, with the kit-based position/signals/agents/CTAs preserved.
class CompanyPage extends ConsumerWidget {
  const CompanyPage(this.fund, {super.key});
  final Fund fund;

  Future<void> _open(String? url) async {
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Holding? _heldIn(List<Holding> holdings) {
    for (final h in holdings) {
      if (h.fundId == fund.id) return h;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final cfg = ref.watch(remoteConfigProvider);
    final tint =
        ref.watch(brandColorProvider(fund.id)) ?? categoryColor(fund.category);
    final logoUrl = ref.watch(logoUrlProvider(fund.id));
    final peers = ref.watch(ratesProvider).valueOrNull ?? const <Fund>[];
    final held = _heldIn(ref.watch(holdingsProvider));
    final following = ref.watch(subscriptionsProvider).contains(fund.id);
    final signals = buildSignals(fund, peers,
        bank: ref.watch(snapshotExtrasProvider).templateBank);
    final agents = ref.watch(agentsForCompanyProvider(fund.companyId));
    final d7 = ref.watch(fundDeltaProvider(fund.id));

    final rate = fund.currentRate;
    final netPct = fund.taxFree ? (rate ?? 0) : Tax.net(rate ?? 0);
    final realPct = fund.realRate(cfg.inflationPct);
    final invest = fund.investUrl ?? fund.siteUrl;

    // Rank among same-type, same-currency retail peers on net yield — the same
    // basis as the peer bars below. Null when it can't be ranked meaningfully.
    int? fundRank;
    var rankTotal = 0;
    if (fund.showsYield && rate != null) {
      final wht = cfg.whtPct;
      double net(Fund p) {
        final r = p.currentRate;
        if (r == null) return double.negativeInfinity;
        return p.taxFree ? r : r * (1 - wht / 100);
      }

      final sameSet = peers
          .where((p) =>
              p.retail &&
              p.fundType == fund.fundType &&
              p.currency == fund.currency &&
              p.showsYield &&
              p.currentRate != null)
          .toList()
        ..sort((a, b) => net(b).compareTo(net(a)));
      final i = sameSet.indexWhere((p) => p.id == fund.id);
      if (i >= 0) {
        fundRank = i + 1;
        rankTotal = sameSet.length;
      }
    }

    // ── CMA CIS quarterly composition. Null (section hidden) until the
    // snapshot carries a breakdown for this fund.
    final fc = ref.watch(compositionProvider(fund.id));

    // Manager market position (CMA Table 1 via companies): share + rank.
    final allCompanies = ref.watch(companiesProvider);
    final manager =
        fund.companyId != null ? allCompanies[fund.companyId] : null;
    final rankedCount =
        allCompanies.values.where((co) => co.marketShare != null).length;
    int? managerRank;
    if (manager?.marketShare != null) {
      final ranked = allCompanies.values
          .where((co) => co.marketShare != null)
          .toList()
        ..sort((a, b) => b.marketShare!.compareTo(a.marketShare!));
      final i = ranked.indexWhere((co) => co.id == manager!.id);
      if (i >= 0) managerRank = i + 1;
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.text,
        elevation: 0,
        title: Text('Fund detail',
            style: TextStyle(
                color: c.text, fontSize: 15, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: t('nav.alerts'),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AlertsPage())),
            icon: Icon(Icons.notifications_none, color: c.muted),
          ),
          IconButton(
            tooltip: following ? t('company.following') : t('company.follow'),
            onPressed: () =>
                ref.read(subscriptionsProvider.notifier).toggle(fund.id),
            icon: Icon(
              following ? Icons.star : Icons.star_border,
              color: following ? c.accent : c.muted,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Ambient brand glow behind the top of the page (.cglow).
          Positioned(
            top: -140,
            left: -80,
            right: -80,
            height: 520,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.2, -0.3),
                    radius: 0.85,
                    colors: [tint.withValues(alpha: 0.20), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          ListView(
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              // ── Identity (det-hero) ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    FundLogo(
                        domain: fund.logoDomain,
                        logoUrl: logoUrl,
                        seed: fund.manager,
                        size: 46,
                        brandColor: tint),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fund.name,
                              style: TextStyle(
                                  color: c.text,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                              '${fund.manager} \u00b7 ${_typeName(fund)} \u00b7 ${fund.currency}',
                              style: TextStyle(
                                  color: c.muted,
                                  fontFamily: AkibaFonts.mono,
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Big rate + % gross + inline 7d delta ───────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text.rich(
                      TextSpan(
                        style: TextStyle(
                          color: c.text,
                          fontFamily: AkibaFonts.mono,
                          fontWeight: FontWeight.w600,
                          height: 1,
                        ),
                        children: rate != null
                            ? [
                                TextSpan(
                                    text: rate.toStringAsFixed(2),
                                    style: const TextStyle(
                                        fontSize: 46, letterSpacing: -1.5)),
                                TextSpan(
                                    text: fund.showsYield ? '% gross' : '%',
                                    style: TextStyle(
                                        fontSize: 18, color: c.muted)),
                              ]
                            : [
                                TextSpan(
                                    text: t('common.dash'),
                                    style: const TextStyle(
                                        fontSize: 46, letterSpacing: -1.5)),
                              ],
                      ),
                    ),
                    if (d7 != null && d7 != 0) ...[
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                                d7 > 0
                                    ? Icons.arrow_drop_up
                                    : Icons.arrow_drop_down,
                                size: 18,
                                color: c.delta(d7)),
                            Text(
                                '${d7.abs().toStringAsFixed(2)} ${t('company.pts7d')}',
                                style: TextStyle(
                                    color: c.delta(d7),
                                    fontFamily: AkibaFonts.mono,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Triad: net / real / min ────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: _Triad(
                  netLabel: fund.taxFree
                      ? 'TAX-FREE'
                      : 'NET (${cfg.whtPct.toStringAsFixed(0)}% WHT)',
                  netValue: rate != null ? '${netPct.toStringAsFixed(2)}%' : '\u2014',
                  real: fund.showsYield ? realPct : null,
                  minValue: fund.minInvest != null
                      ? '${fund.currency} ${_commas(fund.minInvest!)}'
                      : '\u2014',
                ),
              ),

              // ── Rank vs same-type peers (context line) ─────────────────
              if (fundRank case final r? when rankTotal > 1)
                _RankLine(
                  rank: r,
                  total: rankTotal,
                  typeLabel: _typeName(fund).toLowerCase(),
                  currency: fund.currency,
                ),

              // ── Rate history (carded) ──────────────────────────────────
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _card(context, child: RateChart(fund.id, color: tint)),
              ),

              // ── Your position (.pos) — only when held ─────────────────
              if (held != null) ...[
                SectionHeader(title: t('company.yourPosition')),
                _position(context, held, netPct,
                    usdKes: ref.watch(usdKesProvider)),
              ],

              // ── Manager · CMA CIS position ─────────────────────────────
              if (manager?.aumKes != null || manager?.marketShare != null) ...[
                _eyebrow(
                    context,
                    'MANAGER${manager?.aumAsOf != null ? ' \u00b7 CMA CIS ${_quarter(manager!.aumAsOf!)}' : ''}'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _card(context,
                      child: _Stat3(
                        aum: manager?.aumKes,
                        rank: managerRank,
                        rankTotal: rankedCount,
                        share: manager?.marketShare,
                      )),
                ),
              ],

              // ── What the fund holds — donut + legend + provenance ──────
              if (fc != null) CompositionPie(fc),

              // ── Vs category leaders — net-yield bars (carded widget) ───
              PeerCompare(fund, tint: tint),

              // ── Fund facts ─────────────────────────────────────────────
              _eyebrow(context, 'FUND FACTS'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _card(context,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _Facts(rows: [
                      if (fund.minInvest != null)
                        _Fact('Min invest',
                            '${fund.currency} ${_commas(fund.minInvest!)}'),
                      if (fund.mgmtFee != null)
                        _Fact('Mgmt fee', '${fund.mgmtFee}% p.a.'),
                      _Fact(
                          'Tax',
                          fund.taxFree
                              ? 'Tax-free'
                              : '${cfg.whtPct.toStringAsFixed(0)}% WHT'),
                      _Fact('Currency', fund.currency),
                      _Fact('Type', _typeName(fund)),
                    ])),
              ),

              // ── Signals ────────────────────────────────────────────────
              if (signals.isNotEmpty) ...[
                SectionHeader(title: t('company.signals')),
                for (var i = 0; i < signals.length; i++)
                  SignalRow(
                    tag: _tagLabel(signals[i].tag),
                    text: signals[i].text,
                    tone: _tone(signals[i].tag),
                    showDivider: i < signals.length - 1,
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Text(t('company.signalsFoot'),
                      style: TextStyle(color: c.faint, fontSize: 9.5)),
                ),
              ],

              // ── Talk to an agent ───────────────────────────────────────
              if (agents.isNotEmpty) ...[
                SectionHeader(title: t('company.talkToAgent')),
                for (var i = 0; i < agents.length; i++)
                  _agentRow(agents[i], tint, i < agents.length - 1),
              ],

              // ── CTAs ───────────────────────────────────────────────────
              if (invest != null)
                CtaFull(
                    label: t('company.fundTopUp'), onTap: () => _open(invest)),
              if (fund.siteUrl != null)
                CtaGhost(
                    label: t('company.officialSite'),
                    onTap: () => _open(fund.siteUrl)),

              Disclaimer(t('company.moneyNote'), center: true),
              const SizedBox(height: 20),
            ],
          ),
        ],
      ),
    );
  }

  // ── Position → kit PositionBlock ──────────────────────────────────────
  Widget _position(BuildContext context, Holding held, double netPct,
      {double? usdKes}) {
    final c = context.c;
    final rate = fund.currentRate ?? 0;
    final daily = fund.taxFree
        ? AccrualEngine.dailyInterest(held.balance, rate)
        : AccrualEngine.dailyInterestNet(held.balance, rate);
    final netLbl = fund.taxFree
        ? t('company.atTaxFree', {'net': netPct.toStringAsFixed(2)})
        : t('company.atNet', {'net': netPct.toStringAsFixed(2)});

    if (held.currency == 'USD') {
      final kesNote = usdKes != null
          ? '\u2248 ${money('KES', (daily * usdKes).round())} \u00b7 $netLbl'
          : netLbl;
      return PositionBlock(
        value: '\$${withCommas(held.balance)}',
        delta: '+\$${daily.toStringAsFixed(2)}/day',
        deltaColor: c.up,
        sub: kesNote,
      );
    }
    return PositionBlock(
      value: money('KES', held.balance),
      delta: '+${money('KES', daily.round())}/day',
      deltaColor: c.up,
      sub: netLbl,
    );
  }

  // ── Agent → kit AgentRow ──────────────────────────────────────────────
  Widget _agentRow(Agent a, Color tint, bool divider) {
    final digits = (a.phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    final sub = [
      if (a.role != null && a.role!.isNotEmpty) a.role!,
      if (a.phone != null && a.phone!.isNotEmpty) a.phone!,
    ].join(' \u00b7 ');
    return AgentRow(
      name: a.name,
      phone: sub,
      avatarColor: tint,
      onCall: a.phone != null ? () => _open('tel:${a.phone}') : null,
      onWhatsApp: (a.whatsapp && digits.isNotEmpty)
          ? () => _open('https://wa.me/$digits')
          : null,
      showDivider: divider,
    );
  }

  SignalTone _tone(SignalTag tag) => switch (tag) {
        SignalTag.strength => SignalTone.positive,
        SignalTag.watch => SignalTone.negative,
        SignalTag.note => SignalTone.neutral,
      };

  String _tagLabel(SignalTag tag) => switch (tag) {
        SignalTag.strength => t('company.tag.strength'),
        SignalTag.watch => t('company.tag.watch'),
        SignalTag.note => t('company.tag.note'),
      };
}

// ── local building blocks (mockup cards) ─────────────────────────────────

Widget _card(BuildContext context, {required Widget child, EdgeInsets? padding}) {
  final c = context.c;
  return Container(
    padding: padding ?? const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: c.s1,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: c.line),
    ),
    child: child,
  );
}

Widget _eyebrow(BuildContext context, String text) {
  final c = context.c;
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
    child: Text(text,
        style: TextStyle(
            color: c.faint,
            fontFamily: AkibaFonts.mono,
            fontSize: 10.5,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w600)),
  );
}

class _RankLine extends StatelessWidget {
  const _RankLine({
    required this.rank,
    required this.total,
    required this.typeLabel,
    required this.currency,
  });
  final int rank;
  final int total;
  final String typeLabel;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: c.s1,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.line),
        ),
        child: Row(
          children: [
            Icon(Icons.trending_up, size: 15, color: c.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: TextStyle(
                      color: c.muted,
                      fontFamily: AkibaFonts.mono,
                      fontSize: 11,
                      height: 1.3),
                  children: [
                    TextSpan(
                        text: '#$rank of $total',
                        style: TextStyle(
                            color: c.accent, fontWeight: FontWeight.w700)),
                    TextSpan(
                        text: ' $currency $typeLabel funds by net yield'),
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

class _Triad extends StatelessWidget {
  const _Triad({
    required this.netLabel,
    required this.netValue,
    required this.real,
    required this.minValue,
  });
  final String netLabel;
  final String netValue;
  final double? real;
  final String minValue;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget divider() => Container(
        width: 1,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 14),
        color: c.line);
    return Row(
      children: [
        _TriadCell(k: netLabel, v: netValue),
        divider(),
        _TriadCell(
          k: 'REAL VS INFL.',
          v: real != null
              ? '${real! >= 0 ? '+' : ''}${real!.toStringAsFixed(2)}%'
              : '\u2014',
          color: real != null ? c.delta(real!) : null,
        ),
        divider(),
        _TriadCell(k: 'MIN INVEST', v: minValue),
      ],
    );
  }
}

class _TriadCell extends StatelessWidget {
  const _TriadCell({required this.k, required this.v, this.color});
  final String k;
  final String v;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k,
              style: TextStyle(
                  color: c.faint,
                  fontFamily: AkibaFonts.mono,
                  fontSize: 9.5,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(v,
              style: TextStyle(
                  color: color ?? c.text,
                  fontFamily: AkibaFonts.mono,
                  fontSize: 16,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _Stat3 extends StatelessWidget {
  const _Stat3({
    required this.aum,
    required this.rank,
    required this.rankTotal,
    required this.share,
  });
  final double? aum;
  final int? rank;
  final int rankTotal;
  final double? share;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget divider() => Container(
        width: 1,
        height: 34,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: c.line);
    return Row(
      children: [
        _StatCell(
            k: 'MANAGER AUM',
            v: aum != null ? FundComposition.kesShort(aum!) : '\u2014'),
        divider(),
        _StatCell(
            k: 'RANK',
            v: rank != null ? '#$rank / $rankTotal' : '\u2014'),
        divider(),
        _StatCell(
            k: 'MARKET SHARE',
            v: share != null ? '${share!.toStringAsFixed(1)}%' : '\u2014'),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.k, required this.v});
  final String k;
  final String v;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k,
              style: TextStyle(
                  color: c.faint,
                  fontFamily: AkibaFonts.mono,
                  fontSize: 9.5,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(v,
              style: TextStyle(
                  color: c.text,
                  fontFamily: AkibaFonts.mono,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Fact {
  const _Fact(this.k, this.v);
  final String k;
  final String v;
}

class _Facts extends StatelessWidget {
  const _Facts({required this.rows});
  final List<_Fact> rows;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pairs = <List<_Fact>>[];
    for (var i = 0; i < rows.length; i += 2) {
      pairs.add(rows.sublist(i, (i + 2) > rows.length ? rows.length : i + 2));
    }
    Widget cell(_Fact f, {required bool left}) => Padding(
          padding: EdgeInsets.only(
              top: 12, bottom: 12, left: left ? 14 : 0, right: left ? 0 : 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(f.k,
                  style: TextStyle(
                      color: c.faint,
                      fontFamily: AkibaFonts.mono,
                      fontSize: 9.5,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text(f.v,
                  style: TextStyle(
                      color: c.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        );
    return Column(
      children: [
        for (var p = 0; p < pairs.length; p++)
          Container(
            decoration: p < pairs.length - 1
                ? BoxDecoration(
                    border: Border(bottom: BorderSide(color: c.line)))
                : null,
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(child: cell(pairs[p][0], left: false)),
                  Container(width: 1, color: c.line),
                  Expanded(
                    child: pairs[p].length > 1
                        ? cell(pairs[p][1], left: true)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
