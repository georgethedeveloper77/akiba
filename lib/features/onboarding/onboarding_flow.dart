import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_root.dart';
import 'alerts_scene.dart';
import 'splash_scene.dart';

/// Drives the first-launch sequence: splash (~1.5s) → alerts scene → done.
/// On completion flips the persisted `onboarded` flag, which rebuilds AppRoot
/// into the main scaffold.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

enum _Stage { splash, alerts }

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  _Stage _stage = _Stage.splash;

  void _complete() => ref.read(onboardedProvider.notifier).complete();

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: switch (_stage) {
        _Stage.splash => SplashScene(
            key: const ValueKey('splash'),
            onDone: () => setState(() => _stage = _Stage.alerts),
          ),
        _Stage.alerts => AlertsScene(
            key: const ValueKey('alerts'),
            onComplete: _complete,
          ),
      },
    );
  }
}
