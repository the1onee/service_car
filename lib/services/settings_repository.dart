import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barrr/data/collections.dart';
import 'package:barrr/models/app_settings.dart';

class SettingsRepository {
  SettingsRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _settingsRef =>
      _db.collection(Cols.appSettings).doc('main');

  Stream<AppSettings> watchSettings() {
    return _settingsRef.snapshots().map((s) => AppSettings.fromMap(s.data()));
  }

  Future<AppSettings> getSettings() async {
    final snap = await _settingsRef.get();
    return AppSettings.fromMap(snap.data());
  }

  Stream<CityZone?> watchActiveCity() {
    return watchSettings().asyncMap((settings) async {
      final id = settings.activeCityId;
      if (id.isEmpty) return null;
      final doc = await _db.collection(Cols.cities).doc(id).get();
      if (!doc.exists) return null;
      final zone = CityZone.fromDoc(doc);
      return zone.active ? zone : null;
    });
  }

  Future<CityZone?> getActiveCity() async {
    final settings = await getSettings();
    final id = settings.activeCityId;
    if (id.isEmpty) return null;
    final doc = await _db.collection(Cols.cities).doc(id).get();
    if (!doc.exists) return null;
    final zone = CityZone.fromDoc(doc);
    return zone.active ? zone : null;
  }
}
