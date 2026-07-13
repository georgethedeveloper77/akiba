import 'package:flutter/material.dart';

import 'company.dart' show parseHexColor;

/// One declared dividend. Public data (company announcements / annual reports),
/// so this always rides in the snapshot regardless of the price licence.
class StockDividend {
  final int financialYear;
  final String kind; // interim | final | special
  final double dpsKes; // dividend per share, KES
  final String? declaredOn; // YYYY-MM-DD
  final String? bookClosure; // YYYY-MM-DD
  final String? paymentDate; // YYYY-MM-DD
  final String? sourceUrl;

  const StockDividend({
    required this.financialYear,
    required this.kind,
    required this.dpsKes,
    this.declaredOn,
    this.bookClosure,
    this.paymentDate,
    this.sourceUrl,
  });

  factory StockDividend.fromJson(Map<String, dynamic> j) => StockDividend(
    financialYear: (j['financial_year'] as num).toInt(),
    kind: (j['kind'] ?? 'final') as String,
    dpsKes: (j['dps_kes'] as num).toDouble(),
    declaredOn: j['declared_on'] as String?,
    bookClosure: j['book_closure'] as String?,
    paymentDate: j['payment_date'] as String?,
    sourceUrl: j['source_url'] as String?,
  );

  DateTime? get booksCloseAt =>
      bookClosure == null ? null : DateTime.tryParse(bookClosure!);

  /// Days until the register closes. Negative once it has passed, null when the
  /// company has not announced a date (which is common: several 2026 dividends
  /// are printed as SUBJECT TO APPROVAL). Null must render as "not announced",
  /// never as zero days, or the app invents a deadline the company never set.
  int? get daysToBookClosure {
    final d = booksCloseAt;
    if (d == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(d.year, d.month, d.day).difference(today).inDays;
  }

  /// Still buyable for this dividend. To receive it you must be on the register
  /// when the books close, so this is a deadline, not a detail.
  bool get isUpcoming {
    final n = daysToBookClosure;
    return n != null && n >= 0;
  }
}

/// An NSE-listed company.
///
/// Deliberately NOT a Fund: a stock has a ticker, a dividend stream and
/// (conditionally) a price, not a yield. Modelling it as a Fund would have
/// forced a fake `currentRate` onto something that does not have one.
///
/// THE PRICE BLOCK IS NULLABLE ON PURPOSE, but no longer for the reason this
/// comment used to give. It said prices were withheld pending an NSE
/// redistribution licence. They are not: Fructa publishes end-of-day closes,
/// which are facts of public record printed in the Kenyan press every day, and
/// the day change and sparkline are Fructa's own derived figures on its own
/// stored series. `stocks.prices_enabled` is now a KILL SWITCH, not a licence
/// gate: flip it off and every price surface disappears with no release, which
/// is what you want when a parse goes wrong or a source goes down.
///
/// The nullability still matters, for a better reason. A counter that did not
/// trade has no price today, and roughly ten of the sixty four do not trade on
/// a given day. Every price-derived widget is gated on [hasPrice] so those
/// stocks render as a dividend and how-to-buy surface instead of a fake number.
/// Do not "helpfully" default any of these to 0: a missing price is not a price
/// of zero, and a share that did not trade did not trade at nothing.
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

  /// Price / earnings. Null when we have no price, no EPS, or a LOSS.
  ///
  /// The snapshot suppresses it on eps <= 0 rather than publishing a negative
  /// multiple, because "-4.2" is not a cheap stock, it is a meaningless number,
  /// and a reader scanning a triad will read a small figure as good value.
  final double? pe;

  /// The financial year the EPS behind [pe] belongs to. Shown alongside, because
  /// a P/E built from today's price and a three year old EPS is a coincidence,
  /// not a valuation.
  final int? epsYear;
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
    this.pe,
    this.epsYear,
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
    pe: (j['pe'] as num?)?.toDouble(),
    epsYear: (j['eps_year'] as num?)?.toInt(),
    spark: ((j['spark'] as List?) ?? const [])
        .whereType<num>()
        .map((v) => v.toDouble())
        .toList(),
  );

  /// The single gate every price-derived widget checks. False means we have no
  /// price for this counter (it did not trade, or prices are switched off) and
  /// the page must show no price, no day change, no market cap, no yield and no
  /// chart rather than a plausible-looking zero.
  bool get hasPrice => closeKes != null;

  /// The dividend a buyer can still act on: the register has not closed yet.
  /// Null when nothing is pending, which is the normal state most of the year.
  StockDividend? get upcomingDividend {
    StockDividend? soonest;
    for (final d in dividends) {
      if (!d.isUpcoming) continue;
      final n = d.daysToBookClosure!;
      if (soonest == null || n < soonest.daysToBookClosure!) soonest = d;
    }
    return soonest;
  }

  /// A dividend figure exists. This is what makes the page useful even for a
  /// counter that did not trade today.
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
