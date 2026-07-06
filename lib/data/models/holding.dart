class Txn {
  final double amount; // + deposit, - withdrawal
  final String type; // 'deposit' | 'withdrawal'
  final DateTime date;
  const Txn({required this.amount, required this.type, required this.date});

  Map<String, dynamic> toMap() =>
      {'amount': amount, 'type': type, 'date': date.toIso8601String()};

  factory Txn.fromMap(Map m) => Txn(
        amount: (m['amount'] as num).toDouble(),
        type: m['type'] as String,
        date: DateTime.parse(m['date'] as String),
      );
}

class Holding {
  final String fundId;
  final double balance;
  final String currency;
  final DateTime openedAt;
  final List<Txn> transactions;

  const Holding({
    required this.fundId,
    required this.balance,
    required this.currency,
    required this.openedAt,
    this.transactions = const [],
  });

  Map<String, dynamic> toMap() => {
        'fundId': fundId,
        'balance': balance,
        'currency': currency,
        'openedAt': openedAt.toIso8601String(),
        'transactions': transactions.map((t) => t.toMap()).toList(),
      };

  factory Holding.fromMap(Map m) => Holding(
        fundId: m['fundId'] as String,
        balance: (m['balance'] as num).toDouble(),
        currency: m['currency'] as String,
        openedAt: DateTime.parse(m['openedAt'] as String),
        transactions: ((m['transactions'] as List?) ?? const [])
            .map((e) => Txn.fromMap(e as Map))
            .toList(),
      );
}
