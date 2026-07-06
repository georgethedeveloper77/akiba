import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../features/markets/markets_page.dart';
import '../features/portfolio/portfolio_page.dart';
import '../features/settings/settings_page.dart';

/// Selected bottom-tab index. Restored from the pre-A1 scaffold so cross-tab
/// jumps keep working, e.g. Portfolio's empty-state CTA:
///   ref.read(selectedTabProvider.notifier).state = 0;  // → Markets
///
/// Import this from wherever you jump tabs:
///   import '../../app/main_scaffold.dart';
final selectedTabProvider = StateProvider<int>((ref) => 0);

/// Locked v5 navigation: three tabs, no center ＋. Add-holding lives in the
/// Portfolio topbar; Compare is a mode inside Markets (both arrive in B1/B2).
class MainScaffold extends ConsumerWidget {
  const MainScaffold({super.key});

  // Non-const so it works whether or not the page widgets are const-eligible.
  // IndexedStack keeps each tab's state alive across switches.
  static const _pages = [MarketsPage(), PortfolioPage(), SettingsPage()];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final index = ref.watch(selectedTabProvider);

    return Scaffold(
      backgroundColor: c.bg,
      extendBody: true, // let the blurred nav float over content
      body: IndexedStack(index: index, children: _pages),
      bottomNavigationBar: _NavBar(
        index: index,
        onTap: (i) => ref.read(selectedTabProvider.notifier).state = i,
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.activeIcon, this.label);
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

const _items = <_NavItem>[
  _NavItem(
    Icons.stacked_line_chart_outlined,
    Icons.candlestick_chart,
    'Markets',
  ),
  _NavItem(Icons.pie_chart_outline, Icons.pie_chart, 'Portfolio'),
  _NavItem(Icons.settings_outlined, Icons.settings, 'Settings'),
];

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 64 + bottomInset,
          padding: EdgeInsets.only(bottom: bottomInset),
          decoration: BoxDecoration(
            color: c.bg.withValues(alpha: 0.84),
            border: Border(top: BorderSide(color: c.line)),
          ),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _NavCell(
                    item: _items[i],
                    selected: i == index,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavCell extends StatelessWidget {
  const _NavCell({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = selected ? c.accent : c.muted;
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(selected ? item.activeIcon : item.icon, size: 24, color: color),
          const SizedBox(height: 4),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 11,
              height: 1,
              color: color,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
