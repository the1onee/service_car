import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barrr/core/constants.dart';
import 'package:barrr/data/collections.dart';
import 'package:barrr/data/service_catalog.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/service_item.dart';

class UserRepository {
  UserRepository({FirebaseFirestore? db}) : _injected = db;

  final FirebaseFirestore? _injected;
  FirebaseFirestore get _db => _injected ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection(Cols.users).doc(uid);

  Stream<AppUser?> watch(String uid) {
    return _userRef(uid).snapshots().map((d) => d.exists ? AppUser.fromDoc(d) : null);
  }

  Future<AppUser?> get(String uid) async {
    final d = await _userRef(uid).get();
    return d.exists ? AppUser.fromDoc(d) : null;
  }

  Stream<List<AppUser>> watchTechnicians() {
    return _db
        .collection(Cols.users)
        .where('role', isEqualTo: 'technician')
        .snapshots()
        .map((s) => s.docs.map(AppUser.fromDoc).toList());
  }

  Future<void> updateFcm(String uid, String token) {
    return _userRef(uid).set({'fcmToken': token}, SetOptions(merge: true));
  }

  Future<bool> setOnline(String uid, bool online) async {
    if (online) {
      final user = await get(uid);
      if (user == null || !user.canReceiveJobs) return false;
    }
    await _userRef(uid).set({'isOnline': online}, SetOptions(merge: true));
    return true;
  }

  Future<void> setGeo(String uid, GeoPoint geo) {
    return _userRef(uid).set({'geo': geo}, SetOptions(merge: true));
  }

  Future<void> setServiceIds(String uid, List<String> ids) {
    return _userRef(uid).set({'serviceIds': ids}, SetOptions(merge: true));
  }

  Future<void> topUpWallet(String uid, double amount) async {
    if (amount <= 0) return;
    await _db.runTransaction((tx) async {
      final snap = await tx.get(_userRef(uid));
      final current = (snap.data()?['walletBalance'] as num?)?.toDouble() ?? 0;
      tx.set(_userRef(uid), {'walletBalance': current + amount}, SetOptions(merge: true));
    });
  }

  Future<void> setVerification({
    required String uid,
    required bool approved,
  }) {
    return _userRef(uid).set({
      'verified': approved,
      'verificationStatus':
          approved ? VerificationStatus.approved.name : VerificationStatus.rejected.name,
      if (!approved) 'isOnline': false,
    }, SetOptions(merge: true));
  }

  Future<void> applyRating(String uid, int stars) async {
    await _db.runTransaction((tx) async {
      final snap = await tx.get(_userRef(uid));
      final data = snap.data() ?? {};
      final count = (data['ratingCount'] as num?)?.toInt() ?? 0;
      final avg = (data['ratingAvg'] as num?)?.toDouble() ?? 5;
      final nextCount = count + 1;
      final nextAvg = ((avg * count) + stars) / nextCount;
      tx.update(_userRef(uid), {
        'ratingCount': nextCount,
        'ratingAvg': nextAvg,
      });
    });
  }

  Future<void> seedServicesIfNeeded() => syncMvpServices();

  /// يزرع خدمات الإطلاق الناقصة فقط — لا يعطّل ولا يستبدل خدمات أضافها الأدمن.
  Future<void> syncMvpServices() async {
    final existing = await _db.collection(Cols.services).get();
    final existingIds = existing.docs.map((d) => d.id).toSet();
    final missing = seedServices.where((s) => !existingIds.contains(s.id)).toList();
    if (missing.isEmpty) return;
    final batch = _db.batch();
    for (final s in missing) {
      batch.set(_db.collection(Cols.services).doc(s.id), s.toMap());
    }
    await batch.commit();
  }

  Stream<List<ServiceItem>> watchServices() {
    return _db.collection(Cols.services).snapshots().map((s) {
      if (s.docs.isEmpty) return seedServices;
      final list = s.docs
          .map((d) => ServiceItem.fromMap(d.id, d.data()))
          .where((e) => e.active)
          .toList();
      list.sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        if (byOrder != 0) return byOrder;
        return a.titleAr.compareTo(b.titleAr);
      });
      return list;
    });
  }

  String walletHint(AppUser user) {
    final min = AppConstants.minWalletBalance.toStringAsFixed(0);
    final bal = user.walletBalance.toStringAsFixed(0);
    return 'رصيد المحفظة $bal د.ع — الحد الأدنى لاستقبال الطلبات $min د.ع';
  }
}
