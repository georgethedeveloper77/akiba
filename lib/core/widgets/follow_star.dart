import 'package:flutter/material.dart';

import '../i18n.dart';
import '../theme.dart';

/// App-bar follow control. A watchlist star that fills with the subject's brand
/// [tint] when following and outlines when not, with a spring "pop" on every
/// toggle so the state change reads.
///
/// Following is a SUBSCRIPTION, not a bookmark: it drives push. That is why the
/// tooltip says Follow / Following rather than Save.
///
/// This was private to company_page.dart. It is shared now because the stock
/// page needs exactly the same control, and a second copy would have drifted:
/// the star is the only thing standing between a user and a push notification,
/// and two implementations of that is one too many.
class FollowStar extends StatefulWidget {
  const FollowStar({
    super.key,
    required this.following,
    required this.tint,
    required this.onToggle,
  });

  final bool following;
  final Color tint;
  final VoidCallback onToggle;

  @override
  State<FollowStar> createState() => _FollowStarState();
}

class _FollowStarState extends State<FollowStar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );

  late final Animation<double> _pop = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.35,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 38,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.35,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.elasticOut)),
      weight: 62,
    ),
  ]).animate(_ctrl);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _tap() {
    widget.onToggle();
    _ctrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final on = widget.following;
    return IconButton(
      tooltip: on ? t('company.following') : t('company.follow'),
      onPressed: _tap,
      icon: ScaleTransition(
        scale: _pop,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: ScaleTransition(scale: anim, child: child),
          ),
          child: Icon(
            on ? Icons.star_rounded : Icons.star_border_rounded,
            key: ValueKey(on),
            color: on ? widget.tint : c.muted,
          ),
        ),
      ),
    );
  }
}
