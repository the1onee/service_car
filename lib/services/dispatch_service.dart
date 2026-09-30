import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:barrr/data/collections.dart';
import 'package:barrr/models/job_offer.dart';
import 'package:barrr/services/job_repository.dart';

/// يفضّل تنفيذ التوزيع على Cloud Functions، ويعود إلى التنفيذ المحلي عند الفشل.
class DispatchService {
  DispatchService(this._jobs, {FirebaseFunctions? functions}) : _injected = functions;

  final JobRepository _jobs;
  final FirebaseFunctions? _injected;
  FirebaseFunctions get _functions => _injected ?? FirebaseFunctions.instance;

  static const _cfTimeout = Duration(seconds: 10);

  Future<void> dispatch(String jobId) async {
    var isParts = false;
    try {
      final snap = await FirebaseFirestore.instance
          .collection(Cols.jobs)
          .doc(jobId)
          .get()
          .timeout(_cfTimeout);
      final data = snap.data();
      isParts = data?['serviceId'] == 'parts' ||
          data?['providerKind'] == 'workshop';
    } catch (_) {}

    // قطع الغيار: توزيع محلي فقط — استدعاء CF يستهلك المهلة وقد يُفشل قبل إنشاء العروض.
    if (isParts) {
      await _jobs.dispatch(jobId);
      return;
    }

    try {
      final res = await _functions
          .httpsCallable('dispatchJob')
          .call({'jobId': jobId})
          .timeout(_cfTimeout);
      final data = res.data;
      final ok = data == true || (data is Map && data['ok'] == true);
      if (ok) return;
    } catch (_) {}
    await _jobs.dispatch(jobId);
  }

  Future<bool> acceptOffer({
    required String offerId,
    required String technicianId,
    required String technicianName,
    required double initialPrice,
    String partCondition = '',
    int warrantyDays = 0,
    String warrantyNote = '',
    String deliveryType = '',
    String vendorNote = '',
  }) async {
    try {
      final res = await _functions
          .httpsCallable('acceptOffer')
          .call({
            'offerId': offerId,
            'initialPrice': initialPrice,
            if (partCondition.isNotEmpty) 'partCondition': partCondition,
            if (warrantyDays > 0) 'warrantyDays': warrantyDays,
            if (warrantyNote.isNotEmpty) 'warrantyNote': warrantyNote,
            if (deliveryType.isNotEmpty) 'deliveryType': deliveryType,
            if (vendorNote.isNotEmpty) 'vendorNote': vendorNote,
          })
          .timeout(const Duration(seconds: 8));
      return res.data == true || (res.data is Map && res.data['ok'] == true);
    } catch (_) {
      return _jobs.acceptOffer(
        offerId: offerId,
        technicianId: technicianId,
        technicianName: technicianName,
        initialPrice: initialPrice,
        partCondition: partCondition,
        warrantyDays: warrantyDays,
        warrantyNote: warrantyNote,
        deliveryType: deliveryType,
        vendorNote: vendorNote,
      );
    }
  }

  Future<void> onWindowExpired(String jobId) async {
    try {
      await _functions
          .httpsCallable('onWindowExpired')
          .call({'jobId': jobId})
          .timeout(_cfTimeout);
    } catch (_) {
      await _jobs.onWindowExpired(jobId);
    }
  }

  Future<bool> selectOffer({
    required String jobId,
    required JobOffer offer,
  }) async {
    // قطع الغيار: قبول محلي فقط — CF القديمة تضع quoted («بانتظار الموافقة»).
    var isParts = false;
    try {
      final snap = await FirebaseFirestore.instance
          .collection(Cols.jobs)
          .doc(jobId)
          .get()
          .timeout(_cfTimeout);
      final data = snap.data();
      isParts = data?['serviceId'] == 'parts' ||
          data?['providerKind'] == 'workshop';
    } catch (_) {}
    if (isParts) {
      return _jobs.customerSelectOffer(jobId, offer);
    }

    try {
      final res = await _functions
          .httpsCallable('selectOffer')
          .call({
            'jobId': jobId,
            'offerId': offer.id,
          })
          .timeout(_cfTimeout);
      return res.data == true || (res.data is Map && res.data['ok'] == true);
    } catch (_) {
      return _jobs.customerSelectOffer(jobId, offer);
    }
  }
}
