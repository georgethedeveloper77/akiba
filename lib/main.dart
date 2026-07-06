import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/app_root.dart';
import 'app/lock_gate.dart';
import 'core/i18n.dart';
import 'core/push.dart';
import 'core/theme.dart';
import 'core/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('rates'); // cached snapshot + etag
  await Hive.openBox('holdings'); // on-device portfolio
  final settings = await Hive.openBox('settings'); // app lock, prefs, theme
  await Hive.openBox('alerts'); // rate-change feed
  await L10n.load();

  await Push.init();
  final subs = (settings.get('subs', defaultValue: <String>[]) as List)
      .cast<String>()
      .toSet();
  Push.sync(subs);

  runApp(
    ProviderScope(
      // Hand the opened box to the theme controller (and settings prefs).
      overrides: [settingsBoxProvider.overrideWithValue(settings)],
      child: const AkibaApp(),
    ),
  );
}

class AkibaApp extends ConsumerWidget {
  const AkibaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(themeControllerProvider);
    return MaterialApp(
      title: 'Akiba',
      debugShowCheckedModeBanner: false,
      themeMode: t.mode, // System / Light / Dark from Settings
      theme: buildAkibaTheme(brightness: Brightness.light, accent: t.accent),
      darkTheme: buildAkibaTheme(brightness: Brightness.dark, accent: t.accent),
      // Global font-size setting: clamp the OS scale to the user's choice so
      // layouts stay predictable regardless of device accessibility settings.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: t.textScale,
        maxScaleFactor: t.textScale,
        child: child ?? const SizedBox.shrink(),
      ),
      // LockGate (biometric) wraps everything; AppRoot runs onboarding on
      // first launch, then the 3-tab scaffold.
      home: const LockGate(child: AppRoot()),
    );
  }
}
