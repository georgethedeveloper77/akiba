import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n.dart';
import '../../core/push.dart';
import '../../core/settings_prefs.dart';
import '../../core/theme.dart';
import '../../core/widgets/kit.dart';
import '../../data/providers.dart';
import '../../data/snapshot_providers.dart';
import '../backup/backup_ui.dart';
import '../learn/learn_home_page.dart';
import '../blog/blog_page.dart';
import 'widgets/appearance_section.dart';

/// v5 `.pg-settings` - flat rows from the kit, no cards. Sections: Learn
/// (stub until D2, no fabricated streak/star stats), Notifications (master
/// gates children AND drives the OneSignal subscription), Appearance
/// (mode segmented + accent swatches), Security & data.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final prefs = ref.watch(settingsControllerProvider);
    final ctrl = ref.read(settingsControllerProvider.notifier);
    final master = prefs.masterAlerts;
    // Live value the LockGate actually reads; the pref persists the choice.
    final lockOn = ref.watch(appLockProvider);
    final cfg = ref.watch(remoteConfigProvider); // V6 admin-controlled copy

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(top: 4, bottom: 120),
          children: [
            DisplayHeader(
              title: t('settings.title'),
              sub: t('settings.sub'),
            ),
            const SizedBox(height: 16),

            // ── Learn (D2 stub - honest copy, no fake streaks) ────────────
            LearnCard(
              title: cfg.string('learn.card.title', t('settings.learn.title')),
              subtitle: cfg.string(
                  'learn.card.subtitle', t('settings.learn.subtitle')),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LearnHomePage()),
              ),
            ),
            LearnCard(
              icon: Icons.menu_book_outlined,
              title: t('settings.blog.title'),
              subtitle: t('settings.blog.subtitle'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BlogPage()),
              ),
            ),

            SectionHeader(
                title: t('settings.notifications'),
                trailing: t('settings.notif.trailing')),
            const SizedBox(height: 4),
            SettingsRow(
              icon: Icons.notifications_none,
              title: t('settings.notif.master'),
              sub: t('settings.notif.masterSub'),
              trailing: fructaToggle(
                value: master,
                onChanged: (v) {
                  ctrl.setMasterAlerts(v);
                  Push.setEnabled(v); // opt the device in/out at OneSignal
                },
              ),
            ),
            _Gated(
              enabled: master,
              child: Column(children: [
                SettingsRow(
                  icon: Icons.trending_up,
                  title: t('settings.notif.rateMoves'),
                  sub: t('settings.notif.rateMovesSub'),
                  trailing: fructaToggle(
                      value: prefs.rateMoves, onChanged: ctrl.setRateMoves),
                ),
                SettingsRow(
                  icon: Icons.swap_horiz,
                  title: t('settings.notif.saved'),
                  sub: t('settings.notif.savedSub'),
                  trailing: fructaToggle(
                      value: prefs.savedComparisons,
                      onChanged: ctrl.setSavedComparisons),
                ),
                SettingsRow(
                  icon: Icons.paid_outlined,
                  title: t('settings.notif.coupons'),
                  trailing: fructaToggle(
                      value: prefs.couponsMaturities,
                      onChanged: ctrl.setCouponsMaturities),
                ),
                SettingsRow(
                  icon: Icons.newspaper_outlined,
                  title: t('settings.notif.digest'),
                  sub: t('settings.notif.digestSub'),
                  showDivider: false,
                  trailing: fructaToggle(
                      value: prefs.weeklyDigest,
                      onChanged: ctrl.setWeeklyDigest),
                ),
              ]),
            ),

            SectionHeader(title: t('settings.appearance')),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: AppearanceSection(),
            ),

            SectionHeader(title: t('settings.security')),
            const SizedBox(height: 4),
            SettingsRow(
              icon: Icons.lock_outline,
              title: t('settings.security.biometric'),
              sub: t('settings.security.biometricSub'),
              trailing: fructaToggle(
                value: lockOn,
                onChanged: (v) {
                  ref.read(appLockProvider.notifier).state = v;
                  ctrl.setBiometricLock(v); // persisted mirror
                },
              ),
            ),
            SettingsRow(
              icon: Icons.visibility_off_outlined,
              title: t('settings.security.hideBalances'),
              sub: t('settings.security.hideBalancesSub'),
              trailing: fructaToggle(
                  value: prefs.hideBalances,
                  onChanged: ctrl.setHideBalances),
            ),
            SettingsRow(
              icon: Icons.cloud_upload_outlined,
              title: t('settings.data.backup'),
              sub: t('settings.data.backupSub'),
              onTap: () => showBackupSheet(context, ref),
            ),
            SettingsRow(
              icon: Icons.settings_backup_restore,
              title: t('settings.data.restore'),
              sub: t('settings.data.restoreSub'),
              showDivider: false,
              onTap: () => showRestoreSheet(context, ref),
            ),

            Disclaimer(
              t('settings.disclaimer'),
              center: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// Children of the master switch: dimmed + inert while master is off,
/// keeping each child's own stored value intact.
class _Gated extends StatelessWidget {
  const _Gated({required this.enabled, required this.child});
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        ignoring: !enabled,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: enabled ? 1 : 0.45,
          child: child,
        ),
      );
}
