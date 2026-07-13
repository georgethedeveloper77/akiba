/// One stored end-of-day mark for a stock.
///
/// `closeKes` is the NSE's VWAP, the volume-weighted average price for the day,
/// not a last trade. The exchange's daily list has no closing-price column at
/// all: it prints HIGH, LOW, VWAP, PREVIOUS PRICE and VOLUME. Calling this a
/// "close" everywhere would be the kind of small, confident inaccuracy this app
/// exists to argue against, so the UI says "average price" where it has room.
class StockHistory {
  final String asOf; // YYYY-MM-DD
  final double closeKes;

  const StockHistory({required this.asOf, required this.closeKes});

  factory StockHistory.fromJson(Map<String, dynamic> j) => StockHistory(
    asOf: j['as_of'] as String,
    closeKes: (j['close_kes'] as num).toDouble(),
  );
}
