class OilType {
  const OilType({
    required this.id,
    required this.nameAr,
    this.nameEn = '',
    this.noteAr = '',
    this.active = true,
    this.sortOrder = 0,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final String noteAr;
  final bool active;
  final int sortOrder;

  factory OilType.fromMap(String id, Map<String, dynamic> data) {
    final sortRaw = data['sortOrder'];
    return OilType(
      id: id,
      nameAr: data['nameAr'] as String? ?? id,
      nameEn: data['nameEn'] as String? ?? '',
      noteAr: data['noteAr'] as String? ?? '',
      active: data['active'] as bool? ?? true,
      sortOrder: sortRaw is num ? sortRaw.toInt() : 0,
    );
  }
}
