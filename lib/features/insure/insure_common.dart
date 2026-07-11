import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/category_colors.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../core/widgets/kit.dart';
import '../../data/models/insurer.dart';

// ── colour + icon helpers ────────────────────────────────────────────────

/// Parse an insurer brand hex ("#RRGGBB" / "RRGGBB") to a Color, or null. This
/// is a data colour (per-insurer), the documented exception to theme-only.
Color? hexColor(String? hex) {
  if (hex == null) return null;
  var h = hex.trim().replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(v);
}

/// Raw brand colour for an insurer (logo + glow), falling back to the insurance
/// category colour. Use [context.c.brandOnBg] on top for text/stroke legibility.
Color insurerBrand(BuildContext context, Insurer i) =>
    hexColor(i.brandColor) ?? categoryColor('insurance');

/// Material icon for an admin-set type icon name (never an emoji).
IconData insureTypeIcon(String? name) => switch ((name ?? '').toLowerCase()) {
      'motor' || 'car' => Icons.directions_car_outlined,
      'travel' || 'flight' => Icons.flight_outlined,
      'life' => Icons.favorite_outline,
      'medical' || 'health' => Icons.local_hospital_outlined,
      'home' || 'property' => Icons.home_outlined,
      'business' => Icons.business_outlined,
      'marine' => Icons.directions_boat_outlined,
      _ => Icons.shield_outlined,
    };

String regionLabel(String key) => t('insure.region.$key');

double coverNum(String? cover) {
  final m = RegExp(r'[\d.]+').firstMatch(cover ?? '');
  return m == null ? 0 : (double.tryParse(m.group(0)!) ?? 0);
}

// ── shared widgets ───────────────────────────────────────────────────────

/// Row of 5 rating stars (filled to [rating]). Material icons, not glyphs.
class Stars extends StatelessWidget {
  const Stars(this.rating, {super.key, this.size = 12});
  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Icon(i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size, color: c.accent),
      ],
    );
  }
}

/// Section heading matching the mockup `.h2` (mono, optional small trailing).
class InsureH2 extends StatelessWidget {
  const InsureH2(this.title, {super.key, this.small});
  final String title;
  final String? small;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(title,
              style: TextStyle(
                  color: c.text,
                  fontFamily: fructaFonts.mono,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5)),
          if (small != null) ...[
            const SizedBox(width: 9),
            Text(small!, style: TextStyle(color: c.faint, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

/// A comparison quote row (motor + travel share this). Tap opens the detail.
class InsureQuoteRow extends StatelessWidget {
  const InsureQuoteRow({
    super.key,
    required this.name,
    required this.brand,
    required this.priceText,
    required this.onTap,
    this.logoDomain,
    this.stars,
    this.meta,
    this.benefits = const [],
    this.subText,
    this.best = false,
  });

  final String name;
  final Color brand;
  final String priceText;
  final VoidCallback onTap;
  final String? logoDomain;
  final int? stars;
  final String? meta;
  final List<String> benefits;
  final String? subText;
  final bool best;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final shown = benefits.take(3).toList();
    final extra = benefits.length - shown.length;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.line)),
        ),
        child: Stack(
          children: [
            if (best)
              Positioned(
                left: 0,
                top: 10,
                bottom: 10,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: c.up,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FundLogo(
                      domain: logoDomain, seed: name, size: 42, brandColor: brand),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: TextStyle(
                                color: c.text,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (stars != null) Stars(stars!, size: 11),
                            if (meta != null)
                              Flexible(
                                child: Text(
                                    stars != null
                                        ? '  \u00b7  ${meta!}'
                                        : meta!,
                                    style: TextStyle(
                                        color: c.muted, fontSize: 10.5)),
                              ),
                          ],
                        ),
                        if (benefits.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            children: [
                              for (final b in shown) _chip(c, b),
                              if (extra > 0) _chip(c, '+$extra'),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(priceText,
                          style: TextStyle(
                              color: c.text,
                              fontFamily: fructaFonts.mono,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      if (subText != null) ...[
                        const SizedBox(height: 2),
                        Text(subText!,
                            textAlign: TextAlign.end,
                            style: TextStyle(
                                color: c.faint,
                                fontSize: 10,
                                fontFamily: fructaFonts.mono)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(fructaColors c, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
            color: c.s3, borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(color: c.muted, fontSize: 9)),
      );
}

/// One "what's covered" checklist line (dot + label + check).
class CoverRow extends StatelessWidget {
  const CoverRow(this.label, {super.key, required this.tint, this.last = false});
  final String label;
  final Color tint;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border:
            last ? null : Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: tint, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(label,
                style: TextStyle(color: c.muted, fontSize: 12.5)),
          ),
          Icon(Icons.check_rounded, size: 16, color: c.up),
        ],
      ),
    );
  }
}

/// Licensed IRA class chips.
class ClassChips extends StatelessWidget {
  const ClassChips(this.classes, {super.key});
  final List<InsClass> classes;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final cl in classes)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: c.s2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.line),
              ),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                      fontFamily: fructaFonts.mono, fontSize: 10, color: c.muted),
                  children: [
                    TextSpan(
                        text: cl.code,
                        style: TextStyle(
                            color: c.text, fontWeight: FontWeight.w600)),
                    TextSpan(text: '  ${cl.label}'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small footnote under a section (mockup `.sigfoot`).
class InsureFoot extends StatelessWidget {
  const InsureFoot(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Text(text, style: TextStyle(color: c.faint, fontSize: 9.5)),
    );
  }
}

// ── external launch (tel / wa.me / mailto / web) ─────────────────────────
// Requires url_launcher. Failures are swallowed so a missing handler never
// throws into the UI.

Future<void> _open(Uri uri) async {
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

void openTel(String phone) =>
    _open(Uri.parse('tel:${phone.replaceAll(RegExp(r'\s'), '')}'));
void openWhatsApp(String number) =>
    _open(Uri.parse('https://wa.me/${number.replaceAll(RegExp(r'[^0-9]'), '')}'));
void openMail(String email) => _open(Uri.parse('mailto:$email'));
void openWeb(String site) => _open(
    Uri.parse(site.startsWith('http') ? site : 'https://$site'));

String kes(num v) => 'KES ${withCommas(v.round())}';
