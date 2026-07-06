/// An insurer product (funds row, kind='insurance'). Motor is modelled as a
/// percent-of-value rate with a premium floor; travel tiers live in [plans].
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
  final List<TravelPlan> plans;

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
  });

  bool get hasMotor => motorRate != null;

  /// Annual motor premium for a vehicle [value]: rate% of value, rounded to the
  /// nearest 100, floored at min_premium (default 37,500).
  double premium(num value) {
    final rate = motorRate ?? 0;
    final raw = value * rate / 100;
    final rounded = (raw / 100).round() * 100;
    final floor = (minPremium ?? 37500).toDouble();
    return rounded < floor ? floor : rounded.toDouble();
  }

  /// e.g. "2.5% · min 15k"
  String get excessLabel {
    final parts = <String>[];
    if (excessPct != null) parts.add('${excessPct!.toStringAsFixed(1)}%');
    if (excessMin != null) {
      final k = excessMin! >= 1000 ? '${(excessMin! / 1000).round()}k' : '$excessMin';
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
      );
}

class TravelPlan {
  final String name;
  final num price;
  const TravelPlan({required this.name, required this.price});

  factory TravelPlan.fromJson(Map<String, dynamic> j) => TravelPlan(
        name: (j['name'] ?? '') as String,
        price: (j['price'] as num?) ?? 0,
      );
}
