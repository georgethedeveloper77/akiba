/// Kenyan withholding tax on investment interest.
class Tax {
  /// 15% WHT on MMF / bond / T-bill interest. Infrastructure bonds are exempt.
  static const double wht = 0.15;

  static double net(double gross) => gross * (1 - wht);
}
