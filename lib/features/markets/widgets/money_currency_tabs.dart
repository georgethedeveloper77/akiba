import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../markets_controller.dart';

/// Second-tier currency filter, shown only under the Money Market tab. Options
/// (All · KES · USD · …) are derived from the live data, so they track whatever
/// currencies admin publishes. Rendered as a lighter, accent-tinted sub-row so
/// it reads as a refinement of the category above it, not a peer.
class MoneyCurrencyTabs extends ConsumerWidget {
  const MoneyCurrencyTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final ccys = ref.watch(moneyMarketCurrenciesProvider);
    final selected = ref.watch(marketMoneyCcyProvider);
    if (ccys.length < 2) return const SizedBox.shrink();

    final items = <String?>[null, ...ccys]; // null = All

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final ccy = items[i];
          final on = ccy == selected;
          return GestureDetector(
            onTap: () =>
                ref.read(marketMoneyCcyProvider.notifier).state = ccy,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: on ? c.accentSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: on ? c.accent.withValues(alpha: 0.4) : c.line),
              ),
              child: Text(
                ccy ?? 'All',
                style: TextStyle(
                  color: on ? c.accent : c.muted,
                  fontSize: 12.5,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
