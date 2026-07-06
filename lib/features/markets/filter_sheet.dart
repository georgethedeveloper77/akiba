import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import 'market_filters.dart';

void showFilterSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.panel,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => const _FilterSheet(),
  );
}

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(marketFiltersProvider);
    final n = ref.read(marketFiltersProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(
                width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2))),
          ),
          const _Label('Sort'),
          Wrap(spacing: 8, children: [
            _Chip('Highest rate', f.sort == SortBy.rateDesc, () => n.setSort(SortBy.rateDesc)),
            _Chip('Lowest rate', f.sort == SortBy.rateAsc, () => n.setSort(SortBy.rateAsc)),
            _Chip('Name', f.sort == SortBy.name, () => n.setSort(SortBy.name)),
          ]),
          const SizedBox(height: 20),
          const _Label('Currency'),
          Wrap(spacing: 8, children: [
            _Chip('All', f.currency == null, () => n.setCurrency(null)),
            _Chip('KES', f.currency == 'KES', () => n.setCurrency('KES')),
            _Chip('USD', f.currency == 'USD', () => n.setCurrency('USD')),
          ]),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.gold,
            title: const Text('Tax-free only', style: TextStyle(color: AppColors.ink, fontSize: 14)),
            value: f.taxFreeOnly,
            onChanged: n.setTaxFreeOnly,
          ),
        ]),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(),
            style: const TextStyle(color: AppColors.faint, fontSize: 11, letterSpacing: 1)),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Chip(this.label, this.active, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? const Color(0x1AE0B34C) : AppColors.panel2,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? AppColors.gold : AppColors.line),
          ),
          child: Text(label,
              style: TextStyle(color: active ? AppColors.gold : AppColors.mute, fontSize: 13)),
        ),
      );
}
