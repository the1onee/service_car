class VehicleType {
  const VehicleType({
    required this.id,
    required this.nameAr,
    this.nameEn = '',
    this.active = true,
    this.sortOrder = 0,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final bool active;
  final int sortOrder;

  Map<String, dynamic> toMap() => {
        'nameAr': nameAr,
        'nameEn': nameEn,
        'active': active,
        'sortOrder': sortOrder,
      };

  factory VehicleType.fromMap(String id, Map<String, dynamic> data) {
    final sortRaw = data['sortOrder'];
    return VehicleType(
      id: id,
      nameAr: data['nameAr'] as String? ?? id,
      nameEn: data['nameEn'] as String? ?? '',
      active: data['active'] as bool? ?? true,
      sortOrder: sortRaw is num ? sortRaw.toInt() : 0,
    );
  }
}

/// بذور أولية لأنواع الهيكل (صالون / باص…) — ليست شركات أو موديلات.
const seedVehicleTypes = <VehicleType>[
  VehicleType(id: 'sedan', nameAr: 'صالون', nameEn: 'Sedan', sortOrder: 0),
  VehicleType(
      id: 'electric', nameAr: 'كهربائية', nameEn: 'Electric', sortOrder: 10),
  VehicleType(id: 'large', nameAr: 'كبيرة', nameEn: 'Large', sortOrder: 20),
  VehicleType(id: 'bus', nameAr: 'باص', nameEn: 'Bus', sortOrder: 30),
];
