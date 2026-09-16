class ServiceItem {
  const ServiceItem({
    required this.id,
    required this.titleAr,
    required this.category,
    this.isEmergency = false,
    this.active = true,
  });

  final String id;
  final String titleAr;
  final String category;
  final bool isEmergency;
  final bool active;

  Map<String, dynamic> toMap() => {
        'titleAr': titleAr,
        'category': category,
        'isEmergency': isEmergency,
        'active': active,
      };

  factory ServiceItem.fromMap(String id, Map<String, dynamic> data) {
    return ServiceItem(
      id: id,
      titleAr: data['titleAr'] as String? ?? id,
      category: data['category'] as String? ?? '',
      isEmergency: data['isEmergency'] as bool? ?? false,
      active: data['active'] as bool? ?? true,
    );
  }
}
