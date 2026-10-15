import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barrr/data/collections.dart';
import 'package:barrr/features/warranty/warranty_claim_logic.dart';
import 'package:barrr/models/job.dart';
import 'package:barrr/models/warranty_claim.dart';

class WarrantyClaimsRepository {
  WarrantyClaimsRepository({FirebaseFirestore? db}) : _injected = db;

  final FirebaseFirestore? _injected;
  FirebaseFirestore get _db => _injected ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(Cols.warrantyClaims);

  Stream<List<WarrantyClaim>> watchForCustomer(String customerId) {
    return _col
        .where('customerId', isEqualTo: customerId)
        .limit(60)
        .snapshots()
        .map(_mapAndSort);
  }

  Stream<List<WarrantyClaim>> watchForProvider(String providerId) {
    return _col
        .where('providerId', isEqualTo: providerId)
        .limit(60)
        .snapshots()
        .map(_mapAndSort);
  }

  Stream<List<WarrantyClaim>> watchOpenForProvider(String providerId) {
    return watchForProvider(providerId).map(
      (list) => list.where((c) => c.isOpen).toList(growable: false),
    );
  }

  Stream<WarrantyClaim?> watchClaim(String claimId) {
    return _col.doc(claimId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return WarrantyClaim.fromDoc(snap);
    });
  }

  Stream<WarrantyClaim?> watchOpenForJob(String jobId) {
    return _col
        .where('jobId', isEqualTo: jobId)
        .limit(10)
        .snapshots()
        .map((snap) {
      final rows = snap.docs.map(WarrantyClaim.fromDoc).toList();
      for (final c in rows) {
        if (c.isOpen) return c;
      }
      return null;
    });
  }

  List<WarrantyClaim> _mapAndSort(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    final list = snap.docs.map(WarrantyClaim.fromDoc).toList()
      ..sort((a, b) {
        final aa = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bb = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bb.compareTo(aa);
      });
    return list;
  }

  Future<String> createClaim({
    required Job job,
    required String customerId,
    required String claimType,
    String customerNote = '',
    String customerImageUrl = '',
    String providerName = '',
    String providerPhone = '',
  }) async {
    if (customerId != job.customerId) {
      throw StateError('لا تملك هذا الطلب.');
    }
    if (!canOpenWarrantyClaim(job)) {
      throw StateError('الضمان غير متاح لهذا الطلب أو منتهٍ.');
    }
    final providerId = (job.technicianId ?? '').trim();
    if (providerId.isEmpty) {
      throw StateError('لا يوجد مقدم خدمة مرتبط بهذا الضمان.');
    }

    final existingSnap =
        await _col.where('jobId', isEqualTo: job.id).limit(10).get();
    final hasOpen = existingSnap.docs.any((d) {
      final s = WarrantyClaim.statusFromFirestore(d.data()['status'] as String?);
      return claimStatusIsActive(s);
    });
    if (hasOpen) {
      throw StateError('لديك مطالبة ضمان مفتوحة لهذا الطلب.');
    }

    final now = DateTime.now();
    final providerKind = claimProviderKindForJob(job);
    final type = providerKind == 'workshop'
        ? 'part_not_working'
        : claimType.trim();
    if (type.isEmpty) {
      throw StateError('اختر وصف الخلل أولاً.');
    }

    final ref = await _col.add({
      'jobId': job.id,
      'customerId': customerId,
      'providerId': providerId,
      'technicianId': providerId,
      'providerKind': providerKind,
      'claimType': type,
      'reason': WarrantyClaim.claimTypeLabel(type),
      'status': 'open',
      'customerNote': customerNote.trim(),
      'customerImageUrl': customerImageUrl.trim(),
      'providerNote': '',
      'otherIssue': false,
      'otherIssueNote': '',
      'replacementImageUrl': '',
      'serviceTitle': job.serviceTitle ?? job.partName,
      'providerName': providerName.trim().isNotEmpty
          ? providerName.trim()
          : (job.technicianName ?? ''),
      'providerPhone': providerPhone.trim(),
      'respondBy': Timestamp.fromDate(now.add(const Duration(hours: 24))),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'acknowledgedAt': null,
      'resolvedAt': null,
      'notifyEvent': 'created',
    });
    return ref.id;
  }

  Future<void> acknowledge({
    required String claimId,
    required String providerId,
    String providerNote = '',
  }) async {
    final ref = _col.doc(claimId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw StateError('المطالبة غير موجودة.');
      final data = snap.data()!;
      if ((data['providerId'] as String?) != providerId) {
        throw StateError('ليست مطالبتك.');
      }
      final status = WarrantyClaim.statusFromFirestore(data['status'] as String?);
      if (status == WarrantyClaimStatus.resolved) {
        throw StateError('المطالبة منتهية.');
      }
      if (status != WarrantyClaimStatus.open &&
          status != WarrantyClaimStatus.overdue) {
        return;
      }
      tx.update(ref, {
        'status': 'acknowledged',
        'providerNote': providerNote.trim(),
        'acknowledgedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'notifyEvent': 'acknowledged',
      });
    });
  }

  Future<void> markInProgress({
    required String claimId,
    required String providerId,
  }) async {
    final ref = _col.doc(claimId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw StateError('المطالبة غير موجودة.');
      final data = snap.data()!;
      if ((data['providerId'] as String?) != providerId) {
        throw StateError('ليست مطالبتك.');
      }
      final status = WarrantyClaim.statusFromFirestore(data['status'] as String?);
      if (status == WarrantyClaimStatus.resolved) {
        throw StateError('المطالبة منتهية.');
      }
      final patch = <String, dynamic>{
        'status': 'in_progress',
        'updatedAt': FieldValue.serverTimestamp(),
        'notifyEvent': 'in_progress',
      };
      if (status == WarrantyClaimStatus.open ||
          status == WarrantyClaimStatus.overdue) {
        patch['acknowledgedAt'] = FieldValue.serverTimestamp();
      }
      tx.update(ref, patch);
    });
  }

  Future<void> resolvePartShipped({
    required String claimId,
    required String providerId,
    String replacementImageUrl = '',
    String providerNote = '',
  }) async {
    await _resolve(
      claimId: claimId,
      providerId: providerId,
      resolution: WarrantyClaimResolution.partShipped,
      providerNote: providerNote,
      replacementImageUrl: replacementImageUrl,
    );
  }

  Future<void> resolveFixedOnsite({
    required String claimId,
    required String providerId,
    String providerNote = '',
  }) async {
    await _resolve(
      claimId: claimId,
      providerId: providerId,
      resolution: WarrantyClaimResolution.fixedOnsite,
      providerNote: providerNote,
    );
  }

  Future<void> resolveOtherIssue({
    required String claimId,
    required String providerId,
    required String otherIssueNote,
  }) async {
    final note = otherIssueNote.trim();
    if (note.length < 3) {
      throw StateError('اكتب وصف المشكلة الأخرى.');
    }
    await _resolve(
      claimId: claimId,
      providerId: providerId,
      resolution: WarrantyClaimResolution.otherIssueReported,
      otherIssue: true,
      otherIssueNote: note,
      providerNote: note,
    );
  }

  Future<void> _resolve({
    required String claimId,
    required String providerId,
    required WarrantyClaimResolution resolution,
    String providerNote = '',
    String replacementImageUrl = '',
    bool otherIssue = false,
    String otherIssueNote = '',
  }) async {
    final ref = _col.doc(claimId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw StateError('المطالبة غير موجودة.');
      final data = snap.data()!;
      if ((data['providerId'] as String?) != providerId) {
        throw StateError('ليست مطالبتك.');
      }
      final status = WarrantyClaim.statusFromFirestore(data['status'] as String?);
      if (status == WarrantyClaimStatus.resolved) {
        throw StateError('المطالبة منتهية مسبقًا.');
      }
      tx.update(ref, {
        'status': 'resolved',
        'resolution': WarrantyClaim.resolutionToFirestore(resolution),
        'providerNote': providerNote.trim(),
        'replacementImageUrl': replacementImageUrl.trim(),
        'otherIssue': otherIssue,
        'otherIssueNote': otherIssueNote.trim(),
        'resolvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'notifyEvent': 'resolved',
      });
    });
  }
}
