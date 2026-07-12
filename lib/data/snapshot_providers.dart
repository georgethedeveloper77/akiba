import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/agent.dart';
import 'models/company.dart';
import 'models/fund_composition.dart';
import 'models/insurance_type.dart';
import 'models/insurer.dart';
import 'models/learn.dart';
import 'models/market_event.dart';
import 'models/post.dart';
import 'models/remote_config.dart';
import 'models/stock.dart';
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
  (ref) => ref.watch(snapshotExtrasProvider).companies,
);

final marketEventsProvider = Provider<List<MarketEvent>>(
  (ref) => ref.watch(snapshotExtrasProvider).events,
);

final insurersProvider = Provider<List<Insurer>>(
  (ref) => ref.watch(snapshotExtrasProvider).insurers,
);

/// Admin-managed Insure home grid. Falls back to the baked Motor+Travel default
/// when the snapshot carries none, so the grid renders before the first publish.
final insuranceTypesProvider = Provider<List<InsuranceType>>((ref) {
  final types = ref.watch(snapshotExtrasProvider).insuranceTypes;
  return types.isEmpty ? InsuranceType.fallback : types;
});

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
/// recent event  tiles simply show no delta, never a fabricated one.
final fundDeltaProvider = Provider.family<double?, String>(
  (ref, fundId) => ref.watch(snapshotExtrasProvider).deltaFor(fundId),
);

/// CMA holdings breakdown for a fund (quarterly, per the CIS report). Null
/// until the snapshot carries one  the Company "What the fund holds"
/// section hides itself on null, never showing fabricated splits.
final compositionProvider = Provider.family<FundComposition?, String>(
  (ref, fundId) => ref.watch(snapshotExtrasProvider).compositionFor(fundId),
);

/// V6 remote config  admin-edited copy/flags from the snapshot. Every read
/// carries a baked fallback, so this can never break rendering.
final remoteConfigProvider = Provider<RemoteConfig>(
  (ref) => ref.watch(snapshotExtrasProvider).config,
);

/// KES per USD for portfolio conversion. An admin-set `market.usd_kes` (edited
/// in the Config page, rides the snapshot) is authoritative when present, so a
/// stale scraped `fx_rates` row can't produce a wrong total. Falls back to the
/// latest `fx_rates` USD/KES, then null (USD then shown as unavailable rather
/// than converted at a wrong rate).
final usdKesProvider = Provider<double?>((ref) {
  final extras = ref.watch(snapshotExtrasProvider);
  final admin = extras.config.number('market.usd_kes', 0);
  if (admin > 0) return admin;
  return extras.fx['USD/KES'];
});

/// D2 admin-authored learn content (units → lessons → steps). Empty until the
/// snapshot carries it  the Learn surface shows its empty state, never fakes.
final learnProvider = Provider<LearnContent>(
  (ref) => ref.watch(snapshotExtrasProvider).learn,
);

/// D3 blog posts (articles + briefs) from the snapshot, already pinned-first,
/// newest-first. Empty until the snapshot carries any  the Blog surface shows
/// its empty state rather than a fabricated list.
final postsProvider = Provider<List<Post>>(
  (ref) => ref.watch(snapshotExtrasProvider).posts,
);

/// A single post by slug, or null when the snapshot doesn't carry it.
final postBySlugProvider = Provider.family<Post?, String>((ref, slug) {
  for (final p in ref.watch(postsProvider)) {
    if (p.slug == slug) return p;
  }
  return null;
});

/// When the snapshot was last published (local time), or null on a v1/cached
/// body without a stamp. Drives the Markets "Updated …" line honestly.
final snapshotUpdatedProvider = Provider<DateTime?>(
  (ref) => ref.watch(snapshotExtrasProvider).generatedAt,
);

/// Hosted logo for an INSURER, resolved through its company exactly as
/// [logoUrlProvider] does for a fund.
///
/// This was the whole logo bug: every insure surface passed only `logoDomain`
/// to FundLogo and never a `logoUrl`, so an insurer whose company has a real
/// mark in the `logos` bucket still fell through to a monogram. Insurers are
/// rows in `funds`, so they carry `company_id` like any other row; nothing was
/// resolving it.
///
/// Null is a legitimate answer: the 29 insurers seeded straight off the IRA
/// register have no logo and no verified domain, and a monogram is the correct
/// rendering for them. It beats showing another company's mark.
final insurerLogoUrlProvider = Provider.family<String?, String?>((
  ref,
  companyId,
) {
  if (companyId == null) return null;
  return ref.watch(companiesProvider)[companyId]?.logoUrl;
});

/// Agents attached to a company, plus free agents.
final agentsForCompanyProvider = Provider.family<List<Agent>, String?>((
  ref,
  companyId,
) {
  final agents = ref.watch(snapshotExtrasProvider).agents;
  if (companyId == null) return agents.where((a) => a.isFree).toList();
  return agents
      .where((a) => a.isFree || a.companyIds.contains(companyId))
      .toList();
});

// ── Stocks (0047) ───────────────────────────────────────────────────────────

/// NSE-listed equities from the snapshot. Empty until the snapshot carries any,
/// so the Stocks surface shows its empty state rather than a fabricated list.
final stocksProvider = Provider<List<Stock>>(
  (ref) => ref.watch(snapshotExtrasProvider).stocks,
);

final stockByIdProvider = Provider.family<Stock?, String>((ref, id) {
  for (final s in ref.watch(stocksProvider)) {
    if (s.id == id) return s;
  }
  return null;
});

/// CMA-licensed brokers for the "Where to buy" section. Fructa routes out to
/// these and never places a trade.
final brokersProvider = Provider<List<Broker>>(
  (ref) => ref.watch(snapshotExtrasProvider).brokers,
);

/// Whether the snapshot carries licensed NSE prices.
///
/// This is derived from the DATA, not from a local flag: the publisher only
/// emits price fields when `stocks.prices_enabled` is on, so if no stock has a
/// price, the app has no licensed price to show and every price surface hides
/// itself. That means the app can never display market data the backend did not
/// license, even if a build shipped with the price widgets compiled in.
final stockPricesLiveProvider = Provider<bool>((ref) {
  for (final s in ref.watch(stocksProvider)) {
    if (s.hasPrice) return true;
  }
  return false;
});
