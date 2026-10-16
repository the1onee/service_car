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
  /// طلبات القطع تُوزَّع على مستوى المدينة؛ نطاق أوسع من الخدمات الميدانية.
  static const maxPartsMatchKm = 120.0;
  static const warrantyDays = 2;
  static const approxPrecision = 100.0; // ~1km
  static const commissionRate = 0.10;
  static const minWalletBalance = 10000.0;
  /// أقصى عدد مستندات مزودين تُجلب من Firestore في استعلام واحد.
  static const maxProvidersPerQuery = 200;
  /// أقصى عدد مرشحين نهائيين يُرسلون للعميل في جولة واحدة.
  static const maxCandidatesPerDispatch = 50;
  static const minServiceAmount = 3000.0;
  /// أقصى تخفيض مسموح عن العرض المبدئي (20%).
  static const maxPriceReductionRatio = 0.20;

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

  /// أدنى مبلغ مسموح بعد تخفيض حتى 20% من السعر المرجعي.
  /// يُقرَّب لأعلى إلى مضاعف 1000، مع احترام [minServiceAmount].
  static double? minAllowedPriceFromBaseline(num? baseline) {
    if (baseline == null || baseline <= 0) return null;
    final raw = baseline.toDouble() * (1 - maxPriceReductionRatio);
    final ceilThousand = (raw / 1000).ceil() * 1000.0;
    if (ceilThousand < minServiceAmount) return minServiceAmount;
    return ceilThousand;
  }

  /// خطأ إن كان [newPrice] أقل من الحد المسموح نسبةً إلى [baseline].
  static String? priceReductionError(num? newPrice, num? baseline) {
    final minAllowed = minAllowedPriceFromBaseline(baseline);
    if (minAllowed == null || newPrice == null) return null;
    if (newPrice + 0.01 < minAllowed) {
      return 'المبلغ المدخل غير مقبول';
    }
    return null;
  }
}
