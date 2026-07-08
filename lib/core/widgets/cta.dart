import 'package:flutter/material.dart';

import '../theme.dart';

/// When a real [Icon] is supplied to a CTA, drop any leading symbol/whitespace
/// run from the label  so a legacy "+ " / "\u2197 " baked into an i18n string
/// can't double up beside the Material icon (and glyphs can't creep back into
/// CTA labels). Only the leading non-alphanumeric run is removed; interior
/// punctuation like the slash in "Fund / top up" is untouched.
String _labelForIcon(String s) =>
    s.replaceFirst(RegExp(r'^[^\p{L}\p{N}]+', unicode: true), '').trim();

/// v5 `.ctafull`  primary action. `c.text` fill, `c.bg` ink, full-width with
/// a 16px side margin. Pass [icon] for a leading Material glyph (never a
/// unicode character); its colour inherits the button's foreground.
class CtaFull extends StatelessWidget {
  const CtaFull({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.tint,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  /// Optional brand colour. When set, the button fills with [tint] and its
  /// label/icon ink is chosen for legibility on that fill. Defaults to the v5
  /// `c.text` fill / `c.bg` ink.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final text = icon == null ? label : _labelForIcon(label);
    final bg = tint ?? c.text;
    final fg = tint != null ? c.inkOn(tint!) : c.bg;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Flexible(child: Text(text)),
            ],
          ),
        ),
      ),
    );
  }
}

/// v5 `.ctaghost`  secondary action. Transparent, muted text, `line2` border.
/// Pass [icon] for a leading Material glyph; its colour inherits the foreground.
class CtaGhost extends StatelessWidget {
  const CtaGhost({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.tint,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  /// Optional brand colour. When set, the label/icon take [tint] and the border
  /// a softened [tint]. Defaults to the v5 muted text / `line2` border.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final text = icon == null ? label : _labelForIcon(label);
    final fg = tint ?? c.muted;
    final border = tint != null ? tint!.withValues(alpha: 0.55) : c.line2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 9, 16, 0),
      child: SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: fg,
            padding: const EdgeInsets.symmetric(vertical: 13),
            side: BorderSide(color: border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16),
                const SizedBox(width: 8),
              ],
              Flexible(child: Text(text)),
            ],
          ),
        ),
      ),
    );
  }
}
