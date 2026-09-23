import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barrr/core/constants.dart';
import 'package:barrr/data/collections.dart';
import 'package:barrr/data/service_catalog.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/service_item.dart';
import 'package:barrr/models/vehicle_type.dart';
import 'package:barrr/models/wallet_entry.dart';
import 'package:barrr/models/wallet_top_up.dart';

enum OnlineBlock { none, pending, rejected, lowBalance }

class OnlineResult {
  const OnlineResult.ok()
      : block = OnlineBlock.none,
        balance = 0,
        minBalance = 0;

  const OnlineResult.blocked(
    this.block, {
    this.balance = 0,
    this.minBalance = 0,
  });

  final OnlineBlock block;
  final double balance;
  final double minBalance;

  bool get ok => block == OnlineBlock.none;
}

class UserRepository {
  UserRepository({FirebaseFirestore? db}) : _injected = db;

  final FirebaseFirestore? _injected;
  FirebaseFirestore get _db => _injected ?? FirebaseFirestore.instance;
  final _userStreams = <String, Stream<AppUser?>>{};
  Stream<List<ServiceItem>>? _servicesStream;
  Stream<List<VehicleType>>? _vehicleTypesStream;
  final _walletStreams = <String, Stream<List<WalletEntry>>>{};
  final _topUpStreams = <String, Stream<List<WalletTopUp>>>{};

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection(Cols.users).doc(uid);

  Stream<AppUser?> watch(String uid) {
    return _userStreams.putIfAbsent(
      uid,
      () => _userRef(uid).snapshots().map((d) => d.exists ? AppUser.fromDoc(d) : null),
    );
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

  Future<OnlineResult> setOnline(String uid, bool online) async {
    if (!online) {
      await _userRef(uid).set({'isOnline': false}, SetOptions(merge: true));
      return const OnlineResult.ok();
    }
    final user = await get(uid);
    if (user == null || !user.isTechnician) {
      return const OnlineResult.blocked(OnlineBlock.pending);
    }
    if (user.verificationStatus == VerificationStatus.rejected && !user.verified) {
      return const OnlineResult.blocked(OnlineBlock.rejected);
    }
    if (!user.isApproved) {
      return const OnlineResult.blocked(OnlineBlock.pending);
    }
    final settings = await _db.collection(Cols.appSettings).doc('main').get();
    final min = (settings.data()?['minWalletBalance'] as num?)?.toDouble() ??
        AppConstants.minWalletBalance;
    if (user.walletBalance < min) {
      return OnlineResult.blocked(
        OnlineBlock.lowBalance,
        balance: user.walletBalance,
        minBalance: min,
      );
    }
    final patch = <String, dynamic>{'isOnline': true};
    if (user.serviceIds.isEmpty) {
      patch['serviceIds'] = seedServices.map((s) => s.id).toList();
    }
    if (user.vehicleTypeIds.isEmpty) {
      patch['vehicleTypeIds'] = seedVehicleTypes.map((t) => t.id).toList();
    }
    await _userRef(uid).set(patch, SetOptions(merge: true));
    return const OnlineResult.ok();
  }

  Future<void> setGeo(String uid, GeoPoint geo) {
    return _userRef(uid).set({'geo': geo}, SetOptions(merge: true));
  }

  Future<void> setAddressAndGeo(String uid, {required String address, required GeoPoint geo}) {
    return _userRef(uid).set({
      'address': address,
      'geo': geo,
    }, SetOptions(merge: true));
  }

  Future<void> setServiceIds(String uid, List<String> ids) {
    return _userRef(uid).set({'serviceIds': ids}, SetOptions(merge: true));
  }

  Future<void> setVehicleTypeIds(String uid, List<String> ids) {
    return _userRef(uid).set({'vehicleTypeIds': ids}, SetOptions(merge: true));
  }

  Stream<List<WalletEntry>> watchWalletEntries(String uid) {
    return _walletStreams.putIfAbsent(uid, () => _db
        .collection(Cols.walletEntries)
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(40)
        .snapshots()
        .map((s) => s.docs.map(WalletEntry.fromDoc).toList()));
  }

  Stream<List<WalletTopUp>> watchWalletTopUps(String uid) {
    return _topUpStreams.putIfAbsent(uid, () => _db
        .collection(Cols.walletTopUps)
        .where('technicianId', isEqualTo: uid)
        .limit(30)
        .snapshots()
        .map((s) {
      final list = s.docs.map(WalletTopUp.fromDoc).toList();
      list.sort((a, b) {
        final at = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bt = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bt.compareTo(at);
      });
      return list.take(20).toList();
    }));
  }

  Future<String> createWalletTopUp({
    required String technicianId,
    required double amount,
    required String receiptUrl,
    String transferNote = '',
  }) async {
    if (amount <= 0) {
      throw ArgumentError('المبلغ يجب أن يكون أكبر من صفر.');
    }
    if (receiptUrl.trim().isEmpty) {
      throw ArgumentError('فاتورة التحويل مطلوبة.');
    }
    final ref = await _db.collection(Cols.walletTopUps).add({
      'technicianId': technicianId,
      'amount': amount,
      'receiptUrl': receiptUrl.trim(),
      'transferNote': transferNote.trim(),
      'status': 'pending',
      'rejectReason': '',
      'walletEntryId': '',
      'reviewedBy': '',
      'createdAt': FieldValue.serverTimestamp(),
      'reviewedAt': null,
    });
    return ref.id;
  }

  String walletHint(AppUser user, {required double minBalance}) {
    final min = minBalance.toStringAsFixed(0);
    final bal = user.walletBalance.toStringAsFixed(0);
    return 'رصيد المحفظة $bal د.ع — الحد الأدنى لاستقبال الطلبات $min د.ع';
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

  Future<void> syncSeedVehicleTypes() async {
    final existing = await _db.collection(Cols.vehicleTypes).get();
    final existingIds = existing.docs.map((d) => d.id).toSet();
    final missing =
        seedVehicleTypes.where((t) => !existingIds.contains(t.id)).toList();
    if (missing.isEmpty) return;
    final batch = _db.batch();
    for (final t in missing) {
      batch.set(_db.collection(Cols.vehicleTypes).doc(t.id), t.toMap());
    }
    await batch.commit();
  }

  Stream<List<ServiceItem>> watchServices() {
    return _servicesStream ??= _db.collection(Cols.services).snapshots().map((s) {
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

  Stream<List<VehicleType>> watchVehicleTypes() {
    return _vehicleTypesStream ??= _db.collection(Cols.vehicleTypes).snapshots().map((s) {
      if (s.docs.isEmpty) return seedVehicleTypes;
      final list = s.docs
          .map((d) => VehicleType.fromMap(d.id, d.data()))
          .where((e) => e.active)
          .toList();
      list.sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        if (byOrder != 0) return byOrder;
        return a.nameAr.compareTo(b.nameAr);
      });
      return list.isEmpty ? seedVehicleTypes : list;
    });
  }
}
