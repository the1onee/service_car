import 'package:barrr/models/job_offer.dart';
import 'package:barrr/services/job_repository.dart';

/// التوزيع والقبول يتمان من التطبيق على Firestore مباشرة، بدون Cloud Functions.
class DispatchService {
  DispatchService(this._jobs);

  final JobRepository _jobs;

  Future<void> dispatch(String jobId) => _jobs.dispatch(jobId);

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
  }) {
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

  Future<void> onWindowExpired(String jobId) => _jobs.onWindowExpired(jobId);

  Future<bool> selectOffer({
    required String jobId,
    required JobOffer offer,
  }) {
    return _jobs.customerSelectOffer(jobId, offer);
  }
}
