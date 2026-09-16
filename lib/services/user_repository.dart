import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barrr/core/constants.dart';
import 'package:barrr/data/collections.dart';
import 'package:barrr/data/service_catalog.dart';
import 'package:barrr/demo/demo_mode.dart';
import 'package:barrr/demo/demo_store.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/service_item.dart';

class UserRepository {
  UserRepository({FirebaseFirestore? db}) : _injected = db;

  final FirebaseFirestore? _injected;
  FirebaseFirestore get _db => _injected ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection(Cols.users).doc(uid);

  Stream<AppUser?> watch(String uid) {
    if (DemoMode.enabled) return DemoStore.instance.map(() => DemoStore.instance.user(uid));
    return _userRef(uid).snapshots().map((d) => d.exists ? AppUser.fromDoc(d) : null);
  }

  Future<AppUser?> get(String uid) async {
    if (DemoMode.enabled) return DemoStore.instance.user(uid);
    final d = await _userRef(uid).get();
    return d.exists ? AppUser.fromDoc(d) : null;
  }

  Stream<List<AppUser>> watchTechnicians() {
    if (DemoMode.enabled) {
      return DemoStore.instance.map(() => DemoStore.instance.technicians());
    }
    return _db
        .collection(Cols.users)
        .where('role', isEqualTo: 'technician')
        .snapshots()
        .map((s) => s.docs.map(AppUser.fromDoc).toList());
  }

  Future<void> updateFcm(String uid, String token) {
    if (DemoMode.enabled) return Future.value();
    return _userRef(uid).set({'fcmToken': token}, SetOptions(merge: true));
  }

  Future<bool> setOnline(String uid, bool online) async {
    if (DemoMode.enabled) {
      final before = DemoStore.instance.user(uid);
      await DemoStore.instance.setOnline(uid, online);
      final after = DemoStore.instance.user(uid);
      if (online && (after == null || !after.isOnline)) return false;
      return before != null;
    }
    if (online) {
      final user = await get(uid);
      if (user == null || !user.canReceiveJobs) return false;
    }
    await _userRef(uid).set({'isOnline': online}, SetOptions(merge: true));
    return true;
  }

  Future<void> setGeo(String uid, GeoPoint geo) {
    if (DemoMode.enabled) return DemoStore.instance.setGeo(uid, geo);
    return _userRef(uid).set({'geo': geo}, SetOptions(merge: true));
  }

  Future<void> setServiceIds(String uid, List<String> ids) {
    if (DemoMode.enabled) return DemoStore.instance.setServiceIds(uid, ids);
    return _userRef(uid).set({'serviceIds': ids}, SetOptions(merge: true));
  }

  Future<void> topUpWallet(String uid, double amount) async {
    if (DemoMode.enabled) return DemoStore.instance.topUpWallet(uid, amount);
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
    if (DemoMode.enabled) {
      return DemoStore.instance.setVerification(uid: uid, approved: approved);
    }
    return _userRef(uid).set({
      'verified': approved,
      'verificationStatus':
          approved ? VerificationStatus.approved.name : VerificationStatus.rejected.name,
      if (!approved) 'isOnline': false,
    }, SetOptions(merge: true));
  }

  Future<void> applyRating(String uid, int stars) async {
    if (DemoMode.enabled) return DemoStore.instance.applyRating(uid, stars);
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

  Future<void> seedServicesIfNeeded() async {
    if (DemoMode.enabled) return;
    await syncMvpServices();
  }

  Future<void> syncMvpServices() async {
    if (DemoMode.enabled) return;
    final batch = _db.batch();
    final ids = seedServices.map((s) => s.id).toSet();
    for (final s in seedServices) {
      batch.set(_db.collection(Cols.services).doc(s.id), s.toMap(), SetOptions(merge: true));
    }
    final existing = await _db.collection(Cols.services).get();
    for (final d in existing.docs) {
      if (!ids.contains(d.id)) {
        batch.set(d.reference, {'active': false}, SetOptions(merge: true));
      }
    }
    await batch.commit();
  }

  Stream<List<ServiceItem>> watchServices() {
    if (DemoMode.enabled) {
      return DemoStore.instance.map(() => DemoStore.instance.services());
    }
    return _db.collection(Cols.services).snapshots().map((s) {
      if (s.docs.isEmpty) return seedServices;
      return s.docs
          .map((d) => ServiceItem.fromMap(d.id, d.data()))
          .where((e) => e.active)
          .toList();
    });
  }

  String walletHint(AppUser user) {
    final min = AppConstants.minWalletBalance.toStringAsFixed(0);
    final bal = user.walletBalance.toStringAsFixed(0);
    return 'رصيد المحفظة $bal د.ع — الحد الأدنى لاستقبال الطلبات $min د.ع';
  }
}
