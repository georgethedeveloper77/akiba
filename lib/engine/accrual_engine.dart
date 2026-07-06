import 'dart:math' as math;
import 'tax.dart';

/// Daily accrual for money market funds. Rates are quoted as the *effective
/// annual yield*, so the daily rate is derived to compound back to it exactly.
class AccrualEngine {
  static const int daysPerYear = 365;

  /// Effective daily rate from an effective annual rate (%).
  /// (1 + daily)^365 == 1 + annual, by construction.
  static double dailyRate(double annualRatePercent) {
    final r = annualRatePercent / 100.0;
    return math.pow(1 + r, 1 / daysPerYear).toDouble() - 1;
  }

  /// Gross interest earned in one day on [balance].
  static double dailyInterest(double balance, double annualRatePercent) =>
      balance * dailyRate(annualRatePercent);

  /// Net daily interest, after 15% withholding tax.
  static double dailyInterestNet(double balance, double annualRatePercent) =>
      Tax.net(dailyInterest(balance, annualRatePercent));

  /// Value of [balance] after [days], daily-compounded.
  /// When [net], WHT is taken from each day's interest before it reinvests.
  static double accrue(
    double balance,
    double annualRatePercent,
    int days, {
    bool net = false,
  }) {
    final g = dailyRate(annualRatePercent);
    final effective = net ? g * (1 - Tax.wht) : g;
    return balance * math.pow(1 + effective, days).toDouble();
  }

  /// Interest earned over [days] (accrued value minus principal).
  static double interestOver(
    double balance,
    double annualRatePercent,
    int days, {
    bool net = false,
  }) =>
      accrue(balance, annualRatePercent, days, net: net) - balance;
}
