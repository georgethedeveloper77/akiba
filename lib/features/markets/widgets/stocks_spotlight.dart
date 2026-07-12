import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../data/snapshot_providers.dart';

/// Stocks entry point on Markets. Mirrors [InsuranceSpotlight]: one card, a tap
/// target, no numbers.
///
/// WHY THERE IS NO RATE ON THIS CARD, and no Stocks tab in the rate list.
/// Markets ranks things by a comparable headline rate. Stocks have exactly one
/// rate-like figure, dividend yield, and that figure needs a price, which is
/// NSE-licensed data. Declared dividend in raw KES per share is public but is
/// not comparable across companies (it depends on share price and share count),
/// so ranking stocks beside real yields would be dishonest arithmetic dressed
/// as a league table. So stocks live here as a card that routes into their own
/// surface, and the rate list stays a rate list.
///
/// Self-hides when the snapshot carries no stocks, so it never shows an empty
/// promise.
class StocksSpotlight extends ConsumerWidget {
  const StocksSpotlight({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final stocks = ref.watch(stocksProvider);
    if (stocks.isEmpty) return const SizedBox.shrink();

    final sectors = <String>{};
    for (final s in stocks) {
      if (s.sector != null && s.sector!.isNotEmpty) sectors.add(s.sector!);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.s1,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.line),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.s3,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: c.line2),
                ),
                child: Icon(Icons.show_chart, size: 22, color: c.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stocks on the NSE',
                      style: TextStyle(
                        color: c.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sectors.isEmpty
                          ? '${stocks.length} listed companies, dividends and how to buy'
                          : '${stocks.length} companies across ${sectors.length} sectors, dividends and how to buy',
                      style: TextStyle(
                        color: c.muted,
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, size: 20, color: c.faint),
            ],
          ),
        ),
      ),
    );
  }
}
