import 'package:flutter/material.dart';

import '../theme.dart';

/// v5 `.ctafull` — primary action. `c.text` fill, `c.bg` ink, full-width with
/// a 16px side margin.
class CtaFull extends StatelessWidget {
  const CtaFull({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            backgroundColor: c.text,
            foregroundColor: c.bg,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            textStyle:
                const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

/// v5 `.ctaghost` — secondary action. Transparent, muted text, `line2` border.
class CtaGhost extends StatelessWidget {
  const CtaGhost({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 9, 16, 0),
      child: SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: c.muted,
            padding: const EdgeInsets.symmetric(vertical: 13),
            side: BorderSide(color: c.line2),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            textStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}
