import 'package:cloud_functions/cloud_functions.dart';
import 'package:barrr/models/job_offer.dart';
import 'package:barrr/services/job_repository.dart';

/// يفضّل تنفيذ التوزيع على Cloud Functions، ويعود إلى التنفيذ المحلي عند الفشل.
class DispatchService {
  DispatchService(this._jobs, {FirebaseFunctions? functions}) : _injected = functions;

  final JobRepository _jobs;
  final FirebaseFunctions? _injected;
  FirebaseFunctions get _functions => _injected ?? FirebaseFunctions.instance;

  Future<void> dispatch(String jobId) async {
    try {
      final res = await _functions.httpsCallable('dispatchJob').call({'jobId': jobId});
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
      final res = await _functions.httpsCallable('acceptOffer').call({
        'offerId': offerId,
        'initialPrice': initialPrice,
        if (partCondition.isNotEmpty) 'partCondition': partCondition,
        if (warrantyDays > 0) 'warrantyDays': warrantyDays,
        if (warrantyNote.isNotEmpty) 'warrantyNote': warrantyNote,
        if (deliveryType.isNotEmpty) 'deliveryType': deliveryType,
        if (vendorNote.isNotEmpty) 'vendorNote': vendorNote,
      });
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
      await _functions.httpsCallable('onWindowExpired').call({'jobId': jobId});
    } catch (_) {
      await _jobs.onWindowExpired(jobId);
    }
  }

  Future<bool> selectOffer({
    required String jobId,
    required JobOffer offer,
  }) async {
    try {
      final res = await _functions.httpsCallable('selectOffer').call({
        'jobId': jobId,
        'offerId': offer.id,
      });
      return res.data == true || (res.data is Map && res.data['ok'] == true);
    } catch (_) {
      return _jobs.customerSelectOffer(jobId, offer);
    }
  }
}
