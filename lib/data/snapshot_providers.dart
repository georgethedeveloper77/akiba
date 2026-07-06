import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/agent.dart';
import 'models/company.dart';
import 'models/fund_composition.dart';
import 'models/remote_config.dart';
import 'models/insurer.dart';
import 'models/market_event.dart';
import 'providers.dart';
import 'snapshot_extras.dart';

/// Parses the v2 sibling arrays out of the SAME cached snapshot body that
/// ratesProvider already fetched. Recomputes whenever a refresh lands (it
/// watches ratesProvider), reading the freshly-written cache. No second fetch,
/// no changes to providers.dart's RatesNotifier.
final snapshotExtrasProvider = Provider<SnapshotExtras>((ref) {
  ref.watch(ratesProvider); // recompute after each refresh
  final body = ref.watch(ratesCacheProvider).snapshot;
  if (body == null) return SnapshotExtras.empty;
  try {
    return SnapshotExtras.parse(body);
  } catch (_) {
    return SnapshotExtras.empty;
  }
});

final companiesProvider = Provider<Map<String, Company>>(
    (ref) => ref.watch(snapshotExtrasProvider).companies);

final marketEventsProvider = Provider<List<MarketEvent>>(
    (ref) => ref.watch(snapshotExtrasProvider).events);

final insurersProvider = Provider<List<Insurer>>(
    (ref) => ref.watch(snapshotExtrasProvider).insurers);

/// Brand colour for a fund, via its company. Null until C1 data is present.
final brandColorProvider = Provider.family<Color?, String>((ref, fundId) {
  final f = ref.watch(fundsByIdProvider)[fundId];
  final cid = f?.companyId;
  if (cid == null) return null;
  return ref.watch(companiesProvider)[cid]?.brandColor;
});

final logoUrlProvider = Provider.family<String?, String>((ref, fundId) {
  final f = ref.watch(fundsByIdProvider)[fundId];
  final cid = f?.companyId;
  if (cid == null) return null;
  return ref.watch(companiesProvider)[cid]?.logoUrl;
});

/// Event-driven momentum delta for a fund (rate_change payload). Null when no
/// recent event — tiles simply show no delta, never a fabricated one.
final fundDeltaProvider = Provider.family<double?, String>(
    (ref, fundId) => ref.watch(snapshotExtrasProvider).deltaFor(fundId));

/// CMA holdings breakdown for a fund (quarterly, per the CIS report). Null
/// until the snapshot carries one — the Company "What the fund holds"
/// section hides itself on null, never showing fabricated splits.
final compositionProvider = Provider.family<FundComposition?, String>(
    (ref, fundId) => ref.watch(snapshotExtrasProvider).compositionFor(fundId));

/// V6 remote config — admin-edited copy/flags from the snapshot. Every read
/// carries a baked fallback, so this can never break rendering.
final remoteConfigProvider = Provider<RemoteConfig>(
    (ref) => ref.watch(snapshotExtrasProvider).config);

final usdKesProvider = Provider<double?>(
    (ref) => ref.watch(snapshotExtrasProvider).fx['USD/KES']);

/// Agents attached to a company, plus free agents.
final agentsForCompanyProvider =
    Provider.family<List<Agent>, String?>((ref, companyId) {
  final agents = ref.watch(snapshotExtrasProvider).agents;
  if (companyId == null) return agents.where((a) => a.isFree).toList();
  return agents
      .where((a) => a.isFree || a.companyIds.contains(companyId))
      .toList();
});
