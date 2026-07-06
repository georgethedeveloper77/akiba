import 'package:flutter/material.dart';

const categoryColors = <String, Color>{
  'mmf_kes': Color(0xFFE0B34C), // gold
  'mmf_usd': Color(0xFF6AA6F0), // blue
  'tbill': Color(0xFF4FD0B5), // teal
  'bond': Color(0xFFA99BF5), // purple
  'sacco': Color(0xFF34D399), // green
  'stock': Color(0xFFFB6B6B), // red
  'equity': Color(0xFFF0A24C), // amber
  'balanced': Color(0xFF9A8BF3), // iris
  'islamic': Color(0xFF2FB5A0), // emerald
  'reit': Color(0xFF31B7C2), // cyan
  'insurance': Color(0xFF4E8FE8), // sky
};

Color categoryColor(String c) => categoryColors[c] ?? const Color(0xFF8A92A3);

/// Fund-type colours for the market-allocation donut. Data colours (like
/// [categoryColors] and AssetClass), centralised so no widget carries raw hex.
/// Hue assignment mirrors the v6 mockup: MMF gold, FI sky, Equity iris,
/// Balanced ember, Special emerald. Keyed by `funds.fund_type`.
const fundTypeColors = <String, Color>{
  'mmf': Color(0xFFE0B34C), // gold
  'fixed_income': Color(0xFF4E8FE8), // sky
  'equity': Color(0xFF9A8BF3), // iris
  'balanced': Color(0xFFE7784C), // ember
  'special': Color(0xFF2FB5A0), // emerald
};

Color fundTypeColor(String? t) =>
    fundTypeColors[t] ?? const Color(0xFF8A92A3);
