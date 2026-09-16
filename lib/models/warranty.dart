import 'package:cloud_firestore/cloud_firestore.dart';

enum WarrantyType { part, work }

class Warranty {
  const Warranty({
    required this.enabled,
    this.type = WarrantyType.work,
    this.days = 2,
    this.note,
    this.startsAt,
  });

  final bool enabled;
  final WarrantyType type;
  final int days;
  final String? note;
  final DateTime? startsAt;

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'type': type.name,
        'days': days,
        'note': note,
        'startsAt': startsAt,
      };

  factory Warranty.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return const Warranty(enabled: false);
    }
    return Warranty(
      enabled: data['enabled'] as bool? ?? false,
      type: data['type'] == 'part' ? WarrantyType.part : WarrantyType.work,
      days: (data['days'] as num?)?.toInt() ?? 2,
      note: data['note'] as String?,
      startsAt: data['startsAt'] is Timestamp
          ? (data['startsAt'] as Timestamp).toDate()
          : null,
    );
  }
}

class JobRatings {
  const JobRatings({this.customerToTech, this.techToCustomer});

  final int? customerToTech;
  final int? techToCustomer;

  bool get bothDone => customerToTech != null && techToCustomer != null;

  Map<String, dynamic> toMap() => {
        'customerToTech': customerToTech,
        'techToCustomer': techToCustomer,
      };

  factory JobRatings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const JobRatings();
    return JobRatings(
      customerToTech: (data['customerToTech'] as num?)?.toInt(),
      techToCustomer: (data['techToCustomer'] as num?)?.toInt(),
    );
  }
}
