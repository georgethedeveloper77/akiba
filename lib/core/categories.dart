import 'i18n.dart';

/// Legacy `category` keys (mmf_kes, tbill, ...) as opposed to `fund_type`.
/// Kept because tiles, filters and the compare matrix still key off category;
/// see `fundType.*` in the lang file for the authoritative fund_type labels.
const categoryOrder = <String>[
  'mmf_kes',
  'mmf_usd',
  'tbill',
  'bond',
  'equity',
  'balanced',
  'islamic',
  'reit',
  'sacco',
  'stock',
  'insurance',
];

/// Display name for a legacy category key. An unknown key falls through to the
/// key itself rather than rendering blank.
String categoryLabel(String key) =>
    categoryOrder.contains(key) ? t('category.$key') : key;
