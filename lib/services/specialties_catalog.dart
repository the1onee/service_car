import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barrr/data/collections.dart';

class SpecialtyOption {
  const SpecialtyOption({
    required this.id,
    required this.nameAr,
    this.roles = const [],
  });

  final String id;
  final String nameAr;
  final List<String> roles;
}

/// يحمّل اختصاصات الورش من كتالوج الأدمن.
/// [role] مثل `workshop` / `paintShop` / `oilWorkshop` — فارغ الأدوار = مناسب للجميع.
Future<List<SpecialtyOption>> loadWorkshopSpecialties({String? role}) async {
  final snap = await FirebaseFirestore.instance
      .collection(Cols.workshopSpecialties)
      .get();

  final list = <SpecialtyOption>[];
  for (final d in snap.docs) {
    final data = d.data();
    // مطابق للأدمن: active !== false
    if (data['active'] == false) continue;

    final roles = <String>[];
    final rawRoles = data['roles'];
    if (rawRoles is List) {
      for (final r in rawRoles) {
        if (r is String && r.trim().isNotEmpty) roles.add(r.trim());
      }
    }

    if (role != null &&
        role.isNotEmpty &&
        roles.isNotEmpty &&
        !roles.contains(role)) {
      continue;
    }

    final name = (data['nameAr'] as String?)?.trim();
    list.add(
      SpecialtyOption(
        id: d.id,
        nameAr: (name != null && name.isNotEmpty) ? name : d.id,
        roles: roles,
      ),
    );
  }

  list.sort((a, b) => a.nameAr.compareTo(b.nameAr));
  return list;
}
