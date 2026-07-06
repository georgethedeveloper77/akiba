import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../data/models/insurer.dart';
import '../../../data/snapshot_providers.dart';

/// Insurance spotlight → Insure overlay. Pricing is pulled live from the
/// insurers directory (admin-controlled): cheapest motor floor, insurer count,
/// and cheapest travel plan. Falls back to a generic line if pricing is absent.
class InsuranceSpotlight extends ConsumerWidget {
  const InsuranceSpotlight({super.key, required this.onTap});

  final VoidCallback onTap;

  static String _kes(num v) {
    final s = v.round().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return 'KES ${b.toString()}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    const blue = Color(0xFF4E8FE8);
    final insurers = ref.watch(insurersProvider);

    // cheapest motor entry price (the floor anyone can pay)
    num? motorFrom;
    for (final i in insurers.where((i) => i.hasMotor)) {
      final p = i.minPremium;
      if (p != null && (motorFrom == null || p < motorFrom!)) motorFrom = p;
    }
    // cheapest travel plan across all insurers
    num? travelFrom;
    for (final i in insurers) {
      for (final TravelPlan p in i.plans) {
        if (travelFrom == null || p.price < travelFrom!) travelFrom = p.price;
      }
    }
    final n = insurers.length;

    final String title = motorFrom != null
        ? 'Motor cover from ${_kes(motorFrom!)}/yr'
        : 'Compare motor & travel cover';
    final subParts = <String>[
      if (n > 0) '$n ${n == 1 ? 'insurer' : 'insurers'}, one comparison',
      if (travelFrom != null) 'travel from ${_kes(travelFrom!)}',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.line2),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // blue ambient glow (v5 .sglow)
              Positioned(
                left: -80,
                top: -60,
                bottom: -60,
                child: Container(
                  width: 220,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0x244E8FE8), Colors.transparent],
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.shield_outlined, color: blue),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('INSURANCE',
                            style: TextStyle(
                                color: blue,
                                fontSize: 9.5,
                                letterSpacing: 1,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(title,
                            style: TextStyle(
                                color: c.text,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600)),
                        if (subParts.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(subParts.join(' \u00b7 '),
                              style:
                                  TextStyle(color: c.muted, fontSize: 10.5)),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: c.faint),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
