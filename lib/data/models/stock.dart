import 'package:flutter/material.dart';

import 'company.dart' show parseHexColor;

/// One declared dividend. Public data (company announcements / annual reports),
/// so this always rides in the snapshot regardless of the price licence.
class StockDividend {
  final int financialYear;
  final String kind; // interim | final | special
  final double dpsKes; // dividend per share, KES
  final String? paymentDate; // YYYY-MM-DD
  final String? sourceUrl;

  const StockDividend({
    required this.financialYear,
    required this.kind,
    required this.dpsKes,
    this.paymentDate,
    this.sourceUrl,
  });

  factory StockDividend.fromJson(Map<String, dynamic> j) => StockDividend(
    financialYear: (j['financial_year'] as num).toInt(),
    kind: (j['kind'] ?? 'final') as String,
    dpsKes: (j['dps_kes'] as num).toDouble(),
    paymentDate: j['payment_date'] as String?,
    sourceUrl: j['source_url'] as String?,
  );
}

/// An NSE-listed company.
///
/// Deliberately NOT a Fund: a stock has a ticker, a dividend stream and
/// (conditionally) a price, not a yield. Modelling it as a Fund would have
/// forced a fake `currentRate` onto something that does not have one.
///
/// THE PRICE BLOCK IS NULLABLE ON PURPOSE. NSE market data is subject to a
/// redistribution licence, so the snapshot publishes price/change/market cap/
/// yield/spark only when the `stocks.prices_enabled` config key is true. Every
/// price-derived widget below is gated on [hasPrice], which means the page
/// degrades cleanly into a dividend + how-to-buy surface with no licence, and
/// lights up with no app release once one exists. Do not "helpfully" default
/// any of these to 0: a missing price is not a price of zero.
class Stock {
  // Facts. Always present.
  final String id;
  final String ticker;
  final String name;
  final String? sector;
  final String? segment; // MIM | AIM | GEMS
  final String? about;
  final String? logoUrl;
  final Color? brandColor;
  final String? website;
  final String? irUrl;
  final String? listedOn;
  final num? sharesOutstanding;

  // Dividends. Always present.
  final List<StockDividend> dividends;
  final double? dpsLatest; // all kinds in the most recent FY, summed
  final int? dpsYear;

  // Price block. Null unless licensed.
  final double? closeKes;
  final double? prevClose;
  final double? changePct;
  final String? priceAsOf;
  final double? marketCap;
  final double? divYield;
  final List<double> spark;

  const Stock({
    required this.id,
    required this.ticker,
    required this.name,
    this.sector,
    this.segment,
    this.about,
    this.logoUrl,
    this.brandColor,
    this.website,
    this.irUrl,
    this.listedOn,
    this.sharesOutstanding,
    this.dividends = const [],
    this.dpsLatest,
    this.dpsYear,
    this.closeKes,
    this.prevClose,
    this.changePct,
    this.priceAsOf,
    this.marketCap,
    this.divYield,
    this.spark = const [],
  });

  factory Stock.fromJson(Map<String, dynamic> j) => Stock(
    id: j['id'] as String,
    ticker: (j['ticker'] ?? '') as String,
    name: (j['name'] ?? '') as String,
    sector: j['sector'] as String?,
    segment: j['segment'] as String?,
    about: j['about'] as String?,
    logoUrl: j['logo_url'] as String?,
    brandColor: parseHexColor(j['brand_color'] as String?),
    website: j['website'] as String?,
    irUrl: j['ir_url'] as String?,
    listedOn: j['listed_on'] as String?,
    sharesOutstanding: j['shares_outstanding'] as num?,
    dividends: ((j['dividends'] as List?) ?? const [])
        .map((d) => StockDividend.fromJson((d as Map).cast<String, dynamic>()))
        .toList(),
    dpsLatest: (j['dps_latest'] as num?)?.toDouble(),
    dpsYear: (j['dps_year'] as num?)?.toInt(),
    closeKes: (j['close_kes'] as num?)?.toDouble(),
    prevClose: (j['prev_close'] as num?)?.toDouble(),
    changePct: (j['change_pct'] as num?)?.toDouble(),
    priceAsOf: j['price_as_of'] as String?,
    marketCap: (j['market_cap'] as num?)?.toDouble(),
    divYield: (j['div_yield'] as num?)?.toDouble(),
    spark: ((j['spark'] as List?) ?? const [])
        .whereType<num>()
        .map((v) => v.toDouble())
        .toList(),
  );

  /// The single gate every price-derived widget checks. False means the app has
  /// no licensed price and must show no price, no day change, no market cap, no
  /// yield and no chart.
  bool get hasPrice => closeKes != null;

  /// A dividend figure exists. This is what makes the page useful with no
  /// price licence at all.
  bool get hasDividend => dpsLatest != null && dpsLatest! > 0;

  /// Day move direction. Null when there is no price to compare.
  bool? get isUp {
    final ch = changePct;
    return ch == null ? null : ch >= 0;
  }

  /// Absolute day change in KES, or null without both marks.
  double? get changeKes {
    final c = closeKes;
    final p = prevClose;
    if (c == null || p == null) return null;
    return c - p;
  }

  /// Dividends for the latest financial year only, newest kinds first.
  List<StockDividend> get latestYearDividends {
    final y = dpsYear;
    if (y == null) return const [];
    return dividends.where((d) => d.financialYear == y).toList();
  }
}

/// A CMA-licensed stockbroker. Fructa routes the user out to one of these and
/// never holds money or places a trade, so this is a directory, not an order
/// path. Keep it that way: the moment the app takes an order it is a very
/// different regulated product.
class Broker {
  final String id;
  final String name;
  final String? licenseNo;
  final String? blurb;
  final String? phone;
  final String? email;
  final String? website;
  final String? appUrl;
  final String? logoUrl;

  const Broker({
    required this.id,
    required this.name,
    this.licenseNo,
    this.blurb,
    this.phone,
    this.email,
    this.website,
    this.appUrl,
    this.logoUrl,
  });

  factory Broker.fromJson(Map<String, dynamic> j) => Broker(
    id: j['id'] as String,
    name: (j['name'] ?? '') as String,
    licenseNo: j['license_no'] as String?,
    blurb: j['blurb'] as String?,
    phone: j['phone'] as String?,
    email: j['email'] as String?,
    website: j['website'] as String?,
    appUrl: j['app_url'] as String?,
    logoUrl: j['logo_url'] as String?,
  );

  /// Where "Trade" sends the user. App link first, then the website.
  String? get openUrl => appUrl ?? website;
}
