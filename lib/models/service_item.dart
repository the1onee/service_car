class ServiceItem {
  const ServiceItem({
    required this.id,
    required this.titleAr,
    required this.category,
    this.isEmergency = false,
    this.active = true,
    this.commissionPercent = 10,
    this.discountPercent = 0,
    this.descriptionAr = '',
    this.sortOrder = 0,
  });

  final String id;
  final String titleAr;
  final String category;
  final bool isEmergency;
  final bool active;
  /// نسبة استقطاع المنصة من الفني (0–100).
  final double commissionPercent;
  /// نسبة خصم ترويجي تظهر للزبون (0–100).
  final double discountPercent;
  final String descriptionAr;
  final int sortOrder;

  /// معدل العمولة ككسر (مثلاً 0.10 لـ 10%).
  double get commissionRate => (commissionPercent.clamp(0, 100)) / 100;

  Map<String, dynamic> toMap() => {
        'titleAr': titleAr,
        'category': category,
        'isEmergency': isEmergency,
        'active': active,
        'commissionPercent': commissionPercent,
        'discountPercent': discountPercent,
        'descriptionAr': descriptionAr,
        'sortOrder': sortOrder,
      };

  factory ServiceItem.fromMap(String id, Map<String, dynamic> data) {
    final discountRaw = data['discountPercent'];
    final commissionRaw = data['commissionPercent'];
    final sortRaw = data['sortOrder'];
    return ServiceItem(
      id: id,
      titleAr: data['titleAr'] as String? ?? id,
      category: data['category'] as String? ?? '',
      isEmergency: data['isEmergency'] as bool? ?? false,
      active: data['active'] as bool? ?? true,
      commissionPercent:
          commissionRaw is num ? commissionRaw.toDouble().clamp(0, 100) : 10,
      discountPercent: discountRaw is num ? discountRaw.toDouble().clamp(0, 100) : 0,
      descriptionAr: data['descriptionAr'] as String? ?? '',
      sortOrder: sortRaw is num ? sortRaw.toInt() : 0,
    );
  }
}
