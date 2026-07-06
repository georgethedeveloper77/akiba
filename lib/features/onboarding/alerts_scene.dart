import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/snapshot_providers.dart';
import 'notification_permission.dart';

/// The single onboarding scene: "We watch the rates so you don't." Primary CTA
/// requests OS notification permission, then shows the confirmation sheet and
/// completes. "Maybe later" completes without prompting.
class AlertsScene extends ConsumerWidget {
  const AlertsScene({super.key, required this.onComplete});

  final VoidCallback onComplete;

  Future<void> _turnOn(BuildContext context, WidgetRef ref) async {
    final request = ref.read(notificationPermissionProvider);
    final granted = await request();
    if (!context.mounted) return;
    await _showAlertsOnSheet(context, granted: granted);
    if (context.mounted) onComplete();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final cfg = ref.watch(remoteConfigProvider); // V6 admin-controlled copy
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Icon(Icons.notifications_active_outlined,
                    size: 38, color: c.accent),
              ),
              const SizedBox(height: 28),
              Text(
                cfg.string('onboarding.headline',
                    'We watch the rates\nso you don\u2019t'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 27,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                cfg.string(
                    'onboarding.body',
                    'Get a nudge when a money-market rate moves, a T-bill '
                    'auction prints, or one of your saved comparisons flips '
                    'its leader.'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, height: 1.5, color: c.muted),
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _turnOn(context, ref),
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: c.onAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  child: Text(cfg.string('onboarding.cta', 'Turn on alerts')),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onComplete,
                style: TextButton.styleFrom(foregroundColor: c.muted),
                child: Text(cfg.string('onboarding.later', 'Maybe later')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showAlertsOnSheet(BuildContext context,
    {required bool granted}) {
  final c = context.c;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.s1,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: c.line2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Icon(
              granted ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              size: 44,
              color: granted ? c.up : c.muted,
            ),
            const SizedBox(height: 16),
            Text(
              granted ? 'Alerts are on' : 'No problem',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: c.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              granted
                  ? 'You\u2019ll hear from us only when something meaningful '
                      'moves. Fine-tune everything in Settings.'
                  : 'You can switch alerts on any time from Settings \u203a '
                      'Notifications.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5, color: c.muted),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: c.onAccent,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('See the markets'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
