class AppConstants {
  /// مركز البصرة.
  static const defaultLat = 30.5085;
  static const defaultLng = 47.7830;

  static const emergencyOfferSeconds = 30;
  static const emergencyTechsPerRound = 2;
  static const quoteWindowSeconds = 150;
  static const quoteTechsPerRound = 8;
  static const maxQuotes = 3;
  static const maxDispatchRounds = 3;
  static const maxMatchKm = 25.0;
  static const warrantyDays = 2;
  static const approxPrecision = 100.0; // ~1km
  static const commissionRate = 0.10;
  static const minWalletBalance = 10000.0;
  static const minServiceAmount = 3000.0;

  /// مبلغ الخدمة: 3000 على الأقل، ومن مضاعفات 1000 (ينتهي بـ 000).
  static String? serviceAmountError(num? value) {
    if (value == null) {
      return 'أدخل مبلغاً ينتهي بـ 000، والحد الأدنى 3000';
    }
    final rounded = value.round();
    if ((value - rounded).abs() > 0.01 ||
        rounded < minServiceAmount ||
        rounded % 1000 != 0) {
      return 'أقل مبلغ 3000 ويجب أن ينتهي بـ 000';
    }
    return null;
  }
}
