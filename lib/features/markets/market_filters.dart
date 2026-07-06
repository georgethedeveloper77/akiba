import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/fund.dart';
import '../../data/providers.dart';

enum SortBy { rateDesc, rateAsc, name }

class MarketFilters {
  final String? category; // null = all
  final String? currency; // null = all
  final SortBy sort;
  final bool taxFreeOnly;

  const MarketFilters({
    this.category,
    this.currency,
    this.sort = SortBy.rateDesc,
    this.taxFreeOnly = false,
  });

  MarketFilters copyWith({
    String? category,
    bool clearCategory = false,
    String? currency,
    bool clearCurrency = false,
    SortBy? sort,
    bool? taxFreeOnly,
  }) =>
      MarketFilters(
        category: clearCategory ? null : (category ?? this.category),
        currency: clearCurrency ? null : (currency ?? this.currency),
        sort: sort ?? this.sort,
        taxFreeOnly: taxFreeOnly ?? this.taxFreeOnly,
      );

  int get activeCount =>
      (currency != null ? 1 : 0) + (taxFreeOnly ? 1 : 0) + (sort != SortBy.rateDesc ? 1 : 0);
}

class MarketFiltersNotifier extends Notifier<MarketFilters> {
  @override
  MarketFilters build() => const MarketFilters();

  void toggleCategory(String c) =>
      state = state.category == c ? state.copyWith(clearCategory: true) : state.copyWith(category: c);
  void setCurrency(String? c) =>
      state = c == null ? state.copyWith(clearCurrency: true) : state.copyWith(currency: c);
  void setSort(SortBy s) => state = state.copyWith(sort: s);
  void setTaxFreeOnly(bool v) => state = state.copyWith(taxFreeOnly: v);
}

final marketFiltersProvider =
    NotifierProvider<MarketFiltersNotifier, MarketFilters>(MarketFiltersNotifier.new);

List<Fund> applyFilters(List<Fund> funds, MarketFilters f) {
  final list = funds.where((x) {
    if (f.category != null && x.category != f.category) return false;
    if (f.currency != null && x.currency != f.currency) return false;
    if (f.taxFreeOnly && !x.taxFree) return false;
    return true;
  }).toList();
  switch (f.sort) {
    case SortBy.rateDesc:
      list.sort((a, b) => (b.currentRate ?? 0).compareTo(a.currentRate ?? 0));
    case SortBy.rateAsc:
      list.sort((a, b) => (a.currentRate ?? 0).compareTo(b.currentRate ?? 0));
    case SortBy.name:
      list.sort((a, b) => a.name.compareTo(b.name));
  }
  return list;
}

final filteredFundsProvider = Provider<AsyncValue<List<Fund>>>((ref) {
  final rates = ref.watch(ratesProvider);
  final filters = ref.watch(marketFiltersProvider);
  return rates.whenData((funds) => applyFilters(funds, filters));
});
