import 'package:onesignal_flutter/onesignal_flutter.dart';

// Thin wrapper over OneSignal. Follows are mirrored to per-fund tags so the
// backend can push a rate-change to exactly the users who follow that fund.
// Broadcast opt-ins (weekly digest, market alerts) are mirrored the same way,
// so the server can segment without knowing anything about the user.
class Push {
  static const appId = '85bb4c7a-70df-44d3-99b4-e0bfa8574713';

  /// Set by main() to route a notification tap to the right screen. Kept as a
  /// plain callback so this file has no dependency on the app/router layer.
  static void Function(String target)? onOpenTarget;

  // Must match the backend's tagKey() exactly.
  static String tagKey(String fundId) =>
      'follow_${fundId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';

  /// Stock follows live in their OWN namespace.
  ///
  /// Fund ids and stock ids are both slugs, so `follow_<id>` could in principle
  /// collide across the two tables and a fund follow would silently subscribe
  /// you to a stock. Prefixing removes the possibility entirely. It also means
  /// the existing fund tags on every installed device keep working untouched:
  /// nothing here renames a tag that is already out in the world.
  static String stockTagKey(String stockId) =>
      'follow_stock_${stockId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';

  /// Initialize OneSignal and wire the tap handler. Does NOT request
  /// permission here  the prompt is raised at the onboarding "Turn on alerts"
  /// moment (and from Settings), so first launch never cold-prompts.
  static Future<void> init() async {
    OneSignal.initialize(appId);
    OneSignal.Notifications.addClickListener((event) {
      final target = event.notification.additionalData?['target'];
      if (target is String && target.isNotEmpty) onOpenTarget?.call(target);
    });
  }

  /// Raise the OS notification-permission prompt (the system dialog). Safe to
  /// call more than once — the OS only shows it once, then this reflects the
  /// current grant. Used by onboarding and the first-open follow coach. Returns
  /// whether notifications are permitted.
  static Future<bool> promptPermission() =>
      OneSignal.Notifications.requestPermission(true);

  /// Master switch: opts the device's push subscription in/out at OneSignal,
  /// so "All alerts off" actually stops delivery (the pref alone doesn't).
  static void setEnabled(bool on) {
    if (on) {
      OneSignal.User.pushSubscription.optIn();
    } else {
      OneSignal.User.pushSubscription.optOut();
    }
  }

  static void follow(String fundId) =>
      OneSignal.User.addTags({tagKey(fundId): 'true'});
  static void unfollow(String fundId) =>
      OneSignal.User.removeTag(tagKey(fundId));

  static void followStock(String stockId) =>
      OneSignal.User.addTags({stockTagKey(stockId): 'true'});
  static void unfollowStock(String stockId) =>
      OneSignal.User.removeTag(stockTagKey(stockId));

  /// Re-apply followed STOCK tags on launch, mirroring [sync].
  static void syncStocks(Set<String> stockIds) {
    if (stockIds.isEmpty) return;
    OneSignal.User.addTags({
      for (final id in stockIds) stockTagKey(id): 'true',
    });
  }

  // Re-apply all followed tags on launch (device may have been reset).
  static void sync(Set<String> fundIds) {
    if (fundIds.isEmpty) return;
    OneSignal.User.addTags({for (final id in fundIds) tagKey(id): 'true'});
  }

  /// Weekly-digest opt-in  mirrors the Settings toggle to the server segment.
  static void setDigest(bool on) => on
      ? OneSignal.User.addTags({'digest_weekly': 'true'})
      : OneSignal.User.removeTag('digest_weekly');

  /// Market-wide broadcast opt-in  mirrors the Settings toggle.
  static void setMarketAlerts(bool on) => on
      ? OneSignal.User.addTags({'market_alerts': 'true'})
      : OneSignal.User.removeTag('market_alerts');
}
