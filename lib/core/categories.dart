const categoryLabels = <String, String>{
  'mmf_kes': 'MMF · KES',
  'mmf_usd': 'MMF · USD',
  'tbill': 'T-Bills',
  'bond': 'Bonds',
  'sacco': 'SACCO',
  'stock': 'NSE',
  'equity': 'Equity',
  'balanced': 'Balanced',
  'islamic': 'Islamic',
  'reit': 'REIT',
  'insurance': 'Insurance',
};

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

String categoryLabel(String key) => categoryLabels[key] ?? key;
