import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../core/widgets/kit.dart';
import '../../data/models/agent.dart';
import '../../data/models/insurer.dart';
import '../../data/snapshot_providers.dart';
import 'insure_common.dart';

class InsurerDetailPage extends ConsumerWidget {
  const InsurerDetailPage.motor(this.insurer, {super.key, required this.value})
      : isTravel = false,
        region = null,
        days = 0,
        pax = 0;

  const InsurerDetailPage.travel(
    this.insurer, {
    super.key,
    required this.region,
    required this.days,
    required this.pax,
  })  : isTravel = true,
        value = 0;

  final Insurer insurer;
  final bool isTravel;
  final double value; // motor
  final String? region; // travel
  final int days;
  final int pax;

  SignalTone _tone(String tag) => switch (tag.toUpperCase()) {
        'STRENGTH' => SignalTone.positive,
        'WATCH' => SignalTone.negative,
        _ => SignalTone.neutral,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final i = insurer;
    final brand = insurerBrand(context, i);
    final List<Agent> agents = i.companyId == null
        ? const <Agent>[]
        : ref.watch(agentsForCompanyProvider(i.companyId));

    final years =
        i.licensedSince == null ? null : DateTime.now().year - i.licensedSince!;
    final metaParts = <String>[
      t('insure.generalInsurer'),
      if (i.licensedSince != null)
        t('insure.licensed', {'y': '${i.licensedSince}'}),
      if (years != null) t('insure.years', {'n': '$years'}),
    ];

    final travelPrice =
        isTravel ? (i.travelPrice(region!, days: days, pax: pax) ?? 0) : 0.0;

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
          // identity
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Row(
              children: [
                FundLogo(
                    domain: i.logoDomain,
                    seed: i.name,
                    size: 44,
                    brandColor: brand),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i.name,
                          style: TextStyle(
                              color: c.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(metaParts.join(' \u00b7 '),
                          style: TextStyle(color: c.muted, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // big premium
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isTravel
                      ? t('insure.travelLead', {
                          'region': regionLabel(region!),
                          'days': '$days',
                        })
                      : t('insure.motorLead'),
                  style: TextStyle(color: c.faint, fontSize: 12),
                ),
                const SizedBox(height: 5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(kes(isTravel ? travelPrice : i.premium(value)),
                        style: TextStyle(
                            color: c.text,
                            fontFamily: fructaFonts.mono,
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -1.2)),
                    if (isTravel)
                      Text('  ${t('insure.perTrip')}',
                          style: TextStyle(color: c.muted, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isTravel
                      ? [
                          if (i.travelCover != null) i.travelCover!,
                          pax > 1
                              ? t('insure.travellersN', {'n': '$pax'})
                              : t('insure.travellersN', {'n': '1'}),
                        ].join(' \u00b7 ')
                      : t('insure.rateOfValue', {
                          'rate': (i.motorRate ?? 0).toStringAsFixed(2),
                          'excess': i.excessLabel,
                        }),
                  style: TextStyle(
                      color: c.muted,
                      fontSize: 12.5,
                      fontFamily: fructaFonts.mono),
                ),
              ],
            ),
          ),
          // trust strip
          _TrustStrip(insurer: i),

          // contact
          if (_hasContact(i)) ...[
            InsureH2(t('insure.reachThem'), small: t('insure.reachSmall')),
            _ContactGrid(insurer: i),
          ],

          // cover
          if (i.benefits.isNotEmpty) ...[
            InsureH2(
                isTravel ? t('insure.inThePlan') : t('insure.whatsCovered')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  for (var b = 0; b < i.benefits.length; b++)
                    CoverRow(i.benefits[b],
                        tint: brand, last: b == i.benefits.length - 1),
                ],
              ),
            ),
          ],

          // signals
          if (i.signals.isNotEmpty) ...[
            InsureH2(t('insure.signals')),
            for (var s = 0; s < i.signals.length; s++)
              SignalRow(
                tag: i.signals[s].label,
                text: i.signals[s].text,
                tone: _tone(i.signals[s].tag),
                showDivider: s < i.signals.length - 1,
              ),
            InsureFoot(t('insure.signalsFoot')),
          ],

          // IRA classes
          if (i.classes.isNotEmpty) ...[
            InsureH2(t('insure.classes'), small: t('insure.classesSmall')),
            ClassChips(i.classes),
          ],

          // agents
          if (agents.isNotEmpty) ...[
            InsureH2(t('insure.talkAgent')),
            for (var a = 0; a < agents.length; a++)
              AgentRow(
                name: agents[a].name,
                phone: agents[a].phone ?? '',
                avatarColor: brand,
                onCall: (agents[a].phone ?? '').isEmpty
                    ? null
                    : () => openTel(agents[a].phone!),
                onWhatsApp: (agents[a].whatsapp && agents[a].phone != null)
                    ? () => openWhatsApp(agents[a].phone!)
                    : null,
                showDivider: a < agents.length - 1,
              ),
          ],

          CtaFull(
            label: isTravel
                ? t('insure.getTravelQuote')
                : t('insure.getQuote'),
            tint: brand,
            icon: Icons.north_east,
            onTap: () => _primaryAction(i),
          ),
          if (i.website != null)
            CtaGhost(
              label: t('insure.officialSite'),
              icon: Icons.language,
              onTap: () => openWeb(i.website!),
            ),
          Disclaimer(t('insure.disc.detail')),
        ],
      ),
    );
  }

  void _primaryAction(Insurer i) {
    if (i.phone != null) {
      openTel(i.phone!);
    } else if (i.website != null) {
      openWeb(i.website!);
    }
  }
}

bool _hasContact(Insurer i) =>
    i.phone != null ||
    i.whatsapp != null ||
    i.email != null ||
    i.paybill != null ||
    i.website != null;

class _TrustStrip extends StatelessWidget {
  const _TrustStrip({required this.insurer});
  final Insurer insurer;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final i = insurer;
    Widget cell(String k, String v, String s,
        {bool first = false, Color? vColor}) {
      return Expanded(
        child: Container(
          padding: EdgeInsets.only(left: first ? 0 : 13),
          decoration: BoxDecoration(
            border: first ? null : Border(left: BorderSide(color: c.line)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(k,
                  style: TextStyle(
                      color: c.faint,
                      fontSize: 9.5,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
              Text(v,
                  style: TextStyle(
                      color: vColor ?? c.text,
                      fontFamily: fructaFonts.mono,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(s,
                  style: TextStyle(
                      color: c.faint,
                      fontSize: 9.5,
                      fontFamily: fructaFonts.mono)),
            ],
          ),
        ),
      );
    }

    final dash = t('common.dash');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          cell(
            t('insure.trust.claimsPaid'),
            i.settlePct == null ? dash : '${i.settlePct!.round()}%',
            t('insure.trust.iraSource'),
            first: true,
            vColor: c.accent,
          ),
          cell(
            t('insure.trust.rating'),
            i.rating == null ? dash : '${i.rating}',
            t('insure.trust.ratingSub'),
          ),
          cell(
            t('insure.trust.settlement'),
            i.claimsDays == null
                ? dash
                : t('insure.days', {'n': '${i.claimsDays}'}),
            t('insure.trust.settlementSub'),
          ),
        ],
      ),
    );
  }
}

class _ContactGrid extends StatelessWidget {
  const _ContactGrid({required this.insurer});
  final Insurer insurer;

  @override
  Widget build(BuildContext context) {
    final i = insurer;
    final tiles = <Widget>[
      if (i.phone != null)
        _ContactTile(
          icon: Icons.call,
          tone: _Tone.call,
          label: t('insure.contact.call'),
          value: i.phone!,
          onTap: () => openTel(i.phone!),
        ),
      if (i.whatsapp != null)
        _ContactTile(
          whatsApp: true,
          tone: _Tone.wa,
          label: t('insure.contact.whatsapp'),
          value: t('insure.contact.chatNow'),
          onTap: () => openWhatsApp(i.whatsapp!),
        ),
      if (i.email != null)
        _ContactTile(
          icon: Icons.mail_outline,
          tone: _Tone.mail,
          label: t('insure.contact.email'),
          value: i.email!,
          onTap: () => openMail(i.email!),
        ),
      if (i.paybill != null)
        _ContactTile(
          icon: Icons.receipt_long_outlined,
          tone: _Tone.pay,
          label: t('insure.contact.paybill'),
          value: i.paybill!,
          onTap: null,
        ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          if (tiles.isNotEmpty)
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 9,
              crossAxisSpacing: 9,
              childAspectRatio: 3.3,
              children: tiles,
            ),
          if (i.website != null) ...[
            const SizedBox(height: 9),
            _ContactTile(
              icon: Icons.language,
              tone: _Tone.web,
              label: t('insure.contact.website'),
              value: i.website!,
              onTap: () => openWeb(i.website!),
            ),
          ],
        ],
      ),
    );
  }
}

enum _Tone { call, wa, mail, pay, web }

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.tone,
    required this.label,
    required this.value,
    required this.onTap,
    this.icon,
    this.whatsApp = false,
  });

  final _Tone tone;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool whatsApp;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (Color bg, Color fg) = switch (tone) {
      _Tone.call => (c.upSoft, c.up),
      _Tone.wa => (const Color(0x2225D366), const Color(0xFF25D366)),
      _Tone.mail => (c.accentSoft, c.accent),
      _Tone.pay => (c.accentSoft, c.accent),
      _Tone.web => (c.s3, c.muted),
    };
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: c.s1,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.line),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: whatsApp
                  ? const WhatsAppMark(size: 17)
                  : Icon(icon, size: 15, color: fg),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: c.faint,
                          fontSize: 9,
                          letterSpacing: 0.7,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: TextStyle(
                          color: c.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: fructaFonts.mono)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
