/// An insurer product (funds row, kind='insurance'). Motor is modelled as a
/// percent-of-value rate with a premium floor. Travel is region-priced
/// ([travelRegions]: a base per-traveller price for ea/af/ww/sch), scaled by
/// trip length and traveller count. The legacy [plans] tiers are kept for
/// back-compat but superseded by the region model.
class Insurer {
  final String id;
  final String name;
  final String? companyId;
  final String currency;
  final double? motorRate; // % of vehicle value
  final num? minPremium;
  final double? excessPct;
  final num? excessMin;
  final int? claimsDays;
  final int? rating; // 1..5 stars
  final List<String> benefits;
  final String? logoDomain;
  final List<TravelPlan> plans; // legacy named tiers

  // IN-3 detail surface (migration 0039).
  final double? settlePct; // IRA claims-paid %
  final int? licensedSince; // year licensed
  final String? phone;
  final String? whatsapp; // wa.me number
  final String? email;
  final String? paybill;
  final String? website;
  final String? brandColor; // hex, e.g. "#4E8FE8" (parsed by the screen)
  final List<InsClass> classes; // IRA authorized classes
  final List<InsSignal> signals; // objective signals
  final TravelRegions? travelRegions; // {ea,af,ww,sch} base per-traveller price
  final String? travelCover; // headline cover, e.g. "KES 5M med"

  const Insurer({
    required this.id,
    required this.name,
    this.companyId,
    this.currency = 'KES',
    this.motorRate,
    this.minPremium,
    this.excessPct,
    this.excessMin,
    this.claimsDays,
    this.rating,
    this.benefits = const [],
    this.logoDomain,
    this.plans = const [],
    this.settlePct,
    this.licensedSince,
    this.phone,
    this.whatsapp,
    this.email,
    this.paybill,
    this.website,
    this.brandColor,
    this.classes = const [],
    this.signals = const [],
    this.travelRegions,
    this.travelCover,
  });

  bool get hasMotor => motorRate != null;
  bool get hasTravel => travelRegions != null && travelRegions!.isNotEmpty;

  /// Annual motor premium for a vehicle [value]: rate% of value, rounded to the
  /// nearest 100, floored at min_premium (default 37,500).
  double premium(num value) {
    final rate = motorRate ?? 0;
    final raw = value * rate / 100;
    final rounded = (raw / 100).round() * 100;
    final floor = (minPremium ?? 37500).toDouble();
    return rounded < floor ? floor : rounded.toDouble();
  }

  /// Travel price for a booking: base(region) x day-multiplier x travellers,
  /// rounded to the nearest 50. Null when the region carries no base price.
  /// Multiplier tiers: <=7d x1, <=14d x1.6, <=30d x2.4, else x3.6.
  double? travelPrice(String region, {int days = 7, int pax = 1}) {
    final base = travelRegions?.priceFor(region);
    if (base == null) return null;
    final mult = days <= 7
        ? 1.0
        : days <= 14
        ? 1.6
        : days <= 30
        ? 2.4
        : 3.6;
    final raw = base.toDouble() * mult;
    return ((raw / 50).round() * 50 * pax).toDouble();
  }

  /// Cheapest region base, for "from KES X / trip" labels.
  num? get travelFrom => travelRegions?.minPrice;

  /// e.g. "2.5% . min 15k"
  String get excessLabel {
    final parts = <String>[];
    if (excessPct != null) parts.add('${excessPct!.toStringAsFixed(1)}%');
    if (excessMin != null) {
      final k = excessMin! >= 1000
          ? '${(excessMin! / 1000).round()}k'
          : '$excessMin';
      parts.add('min $k');
    }
    return parts.join(' \u00b7 ');
  }

  factory Insurer.fromJson(Map<String, dynamic> j) => Insurer(
    id: j['id'] as String,
    name: (j['name'] ?? '') as String,
    companyId: j['company_id'] as String?,
    currency: (j['currency'] ?? 'KES') as String,
    motorRate: (j['motor_rate'] as num?)?.toDouble(),
    minPremium: j['min_premium'] as num?,
    excessPct: (j['excess_pct'] as num?)?.toDouble(),
    excessMin: j['excess_min'] as num?,
    claimsDays: (j['claims_days'] as num?)?.toInt(),
    rating: (j['rating'] as num?)?.toInt(),
    benefits: ((j['benefits'] as List?) ?? const []).cast<String>(),
    logoDomain: j['logo_domain'] as String?,
    plans: ((j['plans'] as List?) ?? const [])
        .map((p) => TravelPlan.fromJson((p as Map).cast<String, dynamic>()))
        .toList(),
    settlePct: (j['settle_pct'] as num?)?.toDouble(),
    licensedSince: (j['licensed_since'] as num?)?.toInt(),
    phone: j['phone'] as String?,
    whatsapp: j['whatsapp'] as String?,
    email: j['email'] as String?,
    paybill: j['paybill'] as String?,
    website: j['website'] as String?,
    brandColor: j['brand_color'] as String?,
    classes: ((j['classes'] as List?) ?? const [])
        .map((c) => InsClass.fromJson((c as Map).cast<String, dynamic>()))
        .toList(),
    signals: ((j['signals'] as List?) ?? const [])
        .map((s) => InsSignal.fromJson((s as Map).cast<String, dynamic>()))
        .toList(),
    travelRegions: j['travel_regions'] is Map
        ? TravelRegions.fromJson(
            (j['travel_regions'] as Map).cast<String, dynamic>(),
          )
        : null,
    travelCover: j['travel_cover'] as String?,
  );
}

/// Legacy named travel tier. Superseded by [TravelRegions] but retained so a
/// snapshot carrying old `plans` data still parses.
class TravelPlan {
  final String name;
  final num price;
  const TravelPlan({required this.name, required this.price});

  factory TravelPlan.fromJson(Map<String, dynamic> j) => TravelPlan(
    name: (j['name'] ?? '') as String,
    price: (j['price'] as num?) ?? 0,
  );
}

/// Region base prices per traveller for a standard (<=7 day) trip. Keys:
/// ea (East Africa), af (Africa), ww (Worldwide), sch (Schengen).
class TravelRegions {
  static const keys = ['ea', 'af', 'ww', 'sch'];
  final Map<String, num> prices;
  const TravelRegions(this.prices);

  bool get isNotEmpty => prices.values.any((v) => v > 0);

  num? priceFor(String region) {
    final v = prices[region];
    return (v != null && v > 0) ? v : null;
  }

  num? get minPrice {
    final xs = prices.values.where((v) => v > 0);
    return xs.isEmpty ? null : xs.reduce((a, b) => a < b ? a : b);
  }

  factory TravelRegions.fromJson(Map<String, dynamic> j) => TravelRegions({
    for (final k in keys)
      if (j[k] is num) k: j[k] as num,
  });
}

/// An IRA-authorized insurance class chip, e.g. code "07", label "Motor Priv".
class InsClass {
  final String code;
  final String label;
  const InsClass({required this.code, required this.label});

  factory InsClass.fromJson(Map<String, dynamic> j) => InsClass(
    code: (j['code'] ?? '') as String,
    label: (j['label'] ?? '') as String,
  );
}

/// An objective, editor-written signal. [tag] is one of STRENGTH, WATCH, NOTE
/// and drives both the label and the colour on the detail screen.
class InsSignal {
  final String tag; // STRENGTH | WATCH | NOTE
  final String label;
  final String text;
  const InsSignal({required this.tag, required this.label, required this.text});

  factory InsSignal.fromJson(Map<String, dynamic> j) {
    final tag = ((j['tag'] ?? 'NOTE') as String).toUpperCase();
    return InsSignal(
      tag: tag,
      label: (j['label'] ?? tag) as String,
      text: (j['text'] ?? '') as String,
    );
  }
}
