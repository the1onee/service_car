import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barrr/data/collections.dart';

const int kCarYearMin = 1885;
const int kCarYearMax = 2027;

/// سنوات الصنع الافتراضية عند فراغ كتالوج الأدمن.
List<int> fallbackCarYears() {
  return [for (var y = kCarYearMax; y >= kCarYearMin; y--) y];
}

/// يحمّل السنوات النشطة من Firestore، أو الاحتياطي المحلي.
Future<List<int>> loadCarYears() async {
  try {
    final snap =
        await FirebaseFirestore.instance.collection(Cols.carYears).get();
    final years = <int>[];
    for (final d in snap.docs) {
      final data = d.data();
      if (data['active'] == false) continue;
      final raw = data['year'];
      final y = raw is num
          ? raw.round()
          : int.tryParse(d.id) ?? int.tryParse('$raw');
      if (y == null) continue;
      if (y < kCarYearMin || y > kCarYearMax) continue;
      years.add(y);
    }
    if (years.isEmpty) return fallbackCarYears();
    years.sort((a, b) => b.compareTo(a));
    return years;
  } catch (_) {
    return fallbackCarYears();
  }
}
