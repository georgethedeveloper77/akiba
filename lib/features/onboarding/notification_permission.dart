import 'package:flutter_riverpod/flutter_riverpod.dart';

// NOTE: OneSignal is already wired at both ends (Phase 5). This is the one
// line to confirm against your onesignal_flutter version:
//   v5.x  ->  await OneSignal.Notifications.requestPermission(true)  // returns bool
// If you're on v3.x it's:  await OneSignal.shared.promptUserForPushNotificationPermission()
//
// Kept behind a provider so onboarding stays testable (override with a fake in
// widget tests) and so this file has no hard OneSignal import until you enable it.

typedef PermissionRequester = Future<bool> Function();

/// Default requester. Swap the body for the real OneSignal call above, or
/// override `notificationPermissionProvider` in main() / tests.
Future<bool> _requestViaOneSignal() async {
  try {
    // import 'package:onesignal_flutter/onesignal_flutter.dart';
    // return await OneSignal.Notifications.requestPermission(true);
    return true; // TODO(A2→D): replace with the OneSignal call once imported.
  } catch (_) {
    return false;
  }
}

final notificationPermissionProvider =
    Provider<PermissionRequester>((_) => _requestViaOneSignal);
