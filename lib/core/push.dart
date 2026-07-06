import 'package:onesignal_flutter/onesignal_flutter.dart';

// Thin wrapper over OneSignal. Follows are mirrored to per-fund tags so the
// backend can push a rate-change to exactly the users who follow that fund.
class Push {
  static const appId = '85bb4c7a-70df-44d3-99b4-e0bfa8574713';

  // Must match the backend's tagKey() exactly.
  static String tagKey(String fundId) => 'follow_${fundId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';

  static Future<void> init() async {
    OneSignal.initialize(appId);
    await OneSignal.Notifications.requestPermission(true);
  }

  /// Master switch: opts the device's push subscription in/out at OneSignal,
  /// so "All alerts off" actually stops delivery (the pref alone doesn't).
  static void setEnabled(bool on) {
    if (on) {
      OneSignal.User.pushSubscription.optIn();
    } else {
      OneSignal.User.pushSubscription.optOut();
    }
  }

  static void follow(String fundId) => OneSignal.User.addTags({tagKey(fundId): 'true'});
  static void unfollow(String fundId) => OneSignal.User.removeTag(tagKey(fundId));

  // Re-apply all followed tags on launch (device may have been reset).
  static void sync(Set<String> fundIds) {
    if (fundIds.isEmpty) return;
    OneSignal.User.addTags({for (final id in fundIds) tagKey(id): 'true'});
  }
}
