import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'models/alert.dart';
import 'models/fund.dart';
import 'models/holding.dart';
import 'models/rate_history.dart';
import 'sources/local/rates_cache.dart';
import 'sources/remote/rates_api.dart';
import 'repositories/rates_repository.dart';
import 'repositories/holdings_repository.dart';
import '../core/push.dart';

// ── rates ────────────────────────────────────────────────────────────
final ratesApiProvider = Provider((ref) => RatesApi());
final ratesCacheProvider = Provider((ref) => RatesCache(Hive.box('rates')));
final ratesRepositoryProvider = Provider(
  (ref) => RatesRepository(ref.read(ratesApiProvider), ref.read(ratesCacheProvider)),
);

class RatesNotifier extends AsyncNotifier<List<Fund>> {
  RatesRepository get _repo => ref.read(ratesRepositoryProvider);

  @override
  Future<List<Fund>> build() async {
    final cached = await _repo.cachedOrBundled();
    Future.microtask(_refresh);
    return cached;
  }

  Future<void> _refresh() async {
    final old = state.valueOrNull;
    try {
      final fresh = await _repo.fetchIfChanged();
      if (fresh != null) {
        if (old != null) _detectAlerts(old, fresh);
        state = AsyncData(fresh);
      }
    } catch (_) {}
  }

  // On a fresh snapshot, raise an alert for any followed fund whose rate moved.
  void _detectAlerts(List<Fund> old, List<Fund> fresh) {
    final subs = ref.read(subscriptionsProvider);
    if (subs.isEmpty) return;
    final oldById = {for (final f in old) f.id: f};
    final alerts = ref.read(alertsProvider.notifier);
    for (final f in fresh) {
      if (!subs.contains(f.id)) continue;
      final pr = oldById[f.id]?.currentRate;
      final nr = f.currentRate;
      if (pr != null && nr != null && pr != nr) {
        alerts.add(RateAlert(fundId: f.id, oldRate: pr, newRate: nr, at: DateTime.now()));
      }
    }
  }

  Future<void> refresh() => _refresh();
}

final ratesProvider = AsyncNotifierProvider<RatesNotifier, List<Fund>>(RatesNotifier.new);

final fundsByIdProvider = Provider<Map<String, Fund>>((ref) {
  final funds = ref.watch(ratesProvider).valueOrNull ?? const [];
  return {for (final f in funds) f.id: f};
});

final historyProvider =
    FutureProvider.autoDispose.family<List<RateHistory>, String>((ref, fundId) {
  return ref.read(ratesApiProvider).getHistory(fundId);
});

// ── holdings ─────────────────────────────────────────────────────────
final holdingsRepositoryProvider =
    Provider((ref) => HoldingsRepository(Hive.box('holdings')));

class HoldingsNotifier extends Notifier<List<Holding>> {
  HoldingsRepository get _repo => ref.read(holdingsRepositoryProvider);

  @override
  List<Holding> build() => _repo.all();

  Future<void> setBalance(String fundId, String currency, double balance) async {
    await _repo.setBalance(fundId, currency, balance);
    state = _repo.all();
  }

  Future<void> remove(String fundId) async {
    await _repo.remove(fundId);
    state = _repo.all();
  }
}

final holdingsProvider = NotifierProvider<HoldingsNotifier, List<Holding>>(HoldingsNotifier.new);

// ── subscriptions (followed funds) ───────────────────────────────────
class SubscriptionsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() =>
      ((Hive.box('settings').get('subs', defaultValue: <String>[]) as List).cast<String>()).toSet();

  Future<void> toggle(String fundId) async {
    final s = {...state};
    final added = s.add(fundId);
    if (!added) s.remove(fundId);
    await Hive.box('settings').put('subs', s.toList());
    state = s;
    if (added) { Push.follow(fundId); } else { Push.unfollow(fundId); }
  }
}

final subscriptionsProvider =
    NotifierProvider<SubscriptionsNotifier, Set<String>>(SubscriptionsNotifier.new);

// ── alerts feed ──────────────────────────────────────────────────────
class AlertsNotifier extends Notifier<List<RateAlert>> {
  Box get _box => Hive.box('alerts');

  @override
  List<RateAlert> build() {
    final items = _box.values
        .map((v) => RateAlert.fromMap(Map<String, dynamic>.from(v as Map)))
        .toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    return items;
  }

  Future<void> add(RateAlert a) async {
    await _box.add(a.toMap());
    state = [a, ...state];
  }
}

final alertsProvider = NotifierProvider<AlertsNotifier, List<RateAlert>>(AlertsNotifier.new);

final alertsSeenProvider = StateProvider<DateTime>((ref) {
  final s = Hive.box('settings').get('alertsSeen') as String?;
  return s != null ? DateTime.parse(s) : DateTime.fromMillisecondsSinceEpoch(0);
});

final unreadAlertsProvider = Provider<int>((ref) {
  final seen = ref.watch(alertsSeenProvider);
  return ref.watch(alertsProvider).where((a) => a.at.isAfter(seen)).length;
});

// ── settings ─────────────────────────────────────────────────────────
class AppLockNotifier extends Notifier<bool> {
  @override
  bool build() => Hive.box('settings').get('appLock', defaultValue: false) as bool;

  Future<void> set(bool v) async {
    await Hive.box('settings').put('appLock', v);
    state = v;
  }
}

final appLockProvider = NotifierProvider<AppLockNotifier, bool>(AppLockNotifier.new);
