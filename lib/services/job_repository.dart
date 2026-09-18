import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barrr/core/constants.dart';
import 'package:barrr/core/geo.dart';
import 'package:barrr/data/collections.dart';
import 'package:barrr/data/service_catalog.dart';
import 'package:barrr/models/job.dart';
import 'package:barrr/models/job_offer.dart';
import 'package:barrr/models/warranty.dart';

class JobRepository {
  JobRepository({FirebaseFirestore? db}) : _injected = db;

  final FirebaseFirestore? _injected;
  FirebaseFirestore get _db => _injected ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _jobs => _db.collection(Cols.jobs);
  CollectionReference<Map<String, dynamic>> get _offers => _db.collection(Cols.jobOffers);

  Stream<Job?> watchJob(String jobId) {
    return _jobs.doc(jobId).snapshots().map((d) => d.exists ? Job.fromDoc(d) : null);
  }

  Stream<Job?> watchActiveForCustomer(String uid) {
    return _jobs
        .where('customerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(8)
        .snapshots()
        .map(_firstActive);
  }

  Stream<Job?> watchActiveForTechnician(String uid) {
    return _jobs
        .where('technicianId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(8)
        .snapshots()
        .map(_firstActive);
  }

  Stream<List<JobOffer>> watchJobQuotes(String jobId) {
    return _offers.where('jobId', isEqualTo: jobId).snapshots().map((s) {
      final list = s.docs.map(JobOffer.fromDoc).toList();
      list.sort((a, b) => (a.initialPrice ?? 1e12).compareTo(b.initialPrice ?? 1e12));
      return list
          .where((o) => o.status == OfferStatus.submitted || o.status == OfferStatus.accepted)
          .toList();
    });
  }

  Job? _firstActive(QuerySnapshot<Map<String, dynamic>> snap) {
    final active = {
      JobStatus.dispatching,
      JobStatus.offerPending,
      JobStatus.comparing,
      JobStatus.quoted,
      JobStatus.enRoute,
      JobStatus.arrived,
      JobStatus.finalQuote,
      JobStatus.inProgress,
      JobStatus.completed,
    };
    for (final d in snap.docs) {
      final job = Job.fromDoc(d);
      if (active.contains(job.status)) {
        if (job.status == JobStatus.completed && job.ratings.bothDone) continue;
        return job;
      }
    }
    return null;
  }

  Stream<List<JobOffer>> watchPendingOffers(String technicianId) {
    return _offers
        .where('technicianId', isEqualTo: technicianId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs.map(JobOffer.fromDoc).toList());
  }

  Future<String> createJob({
    required String customerId,
    required String serviceId,
    required String serviceTitle,
    required GeoPoint exact,
  }) async {
    final ref = _jobs.doc();
    final emergency = isEmergencyService(serviceId);
    final job = Job(
      id: ref.id,
      customerId: customerId,
      serviceId: serviceId,
      serviceTitle: serviceTitle,
      status: JobStatus.dispatching,
      matchingMode: emergency ? MatchingMode.emergency : MatchingMode.quotes,
      approxLocation: approximate(exact),
      createdAt: DateTime.now(),
    );
    final batch = _db.batch();
    batch.set(ref, job.toCreateMap());
    batch.set(_db.collection('jobLocations').doc(ref.id), {
      'customerId': customerId,
      'exact': exact,
    });
    await batch.commit();
    return ref.id;
  }

  Future<void> dispatch(String jobId) async {
    final jobSnap = await _jobs.doc(jobId).get();
    if (!jobSnap.exists) return;
    final job = Job.fromDoc(jobSnap);
    if (job.technicianId != null) return;
    if (job.status != JobStatus.dispatching && job.status != JobStatus.offerPending) {
      return;
    }

    final techs = await _db
        .collection(Cols.users)
        .where('role', isEqualTo: 'technician')
        .where('isOnline', isEqualTo: true)
        .where('serviceIds', arrayContains: job.serviceId)
        .get();

    final previous = await _offers.where('jobId', isEqualTo: jobId).get();
    final used = previous.docs.map((d) => d.data()['technicianId'] as String?).toSet();

    final ranked = techs.docs
        .map((d) {
          final data = d.data();
          final geo = data['geo'] as GeoPoint?;
          final km = geo == null
              ? 9999.0
              : haversineKm(
                  job.approxLocation.latitude,
                  job.approxLocation.longitude,
                  geo.latitude,
                  geo.longitude,
                );
          final verified = data['verified'] as bool? ?? false;
          final wallet = (data['walletBalance'] as num?)?.toDouble() ?? 0;
          return (
            id: d.id,
            km: km,
            token: data['fcmToken'] as String?,
            name: data['name'] as String? ?? 'فني',
            rating: (data['ratingAvg'] as num?)?.toDouble() ?? 5,
            verified: verified,
            wallet: wallet,
          );
        })
        .where((t) => t.km <= AppConstants.maxMatchKm)
        .where((t) => t.verified)
        .where((t) => t.wallet >= AppConstants.minWalletBalance)
        .where((t) => !used.contains(t.id))
        .toList()
      ..sort((a, b) => a.km.compareTo(b.km));

    final take = job.isEmergency
        ? AppConstants.emergencyTechsPerRound
        : AppConstants.quoteTechsPerRound;
    final chosen = ranked.take(take).toList();
    if (chosen.isEmpty) {
      await _jobs.doc(jobId).update({'status': JobStatus.noTechnician.name});
      return;
    }

    final seconds = job.isEmergency
        ? AppConstants.emergencyOfferSeconds
        : AppConstants.quoteWindowSeconds;
    final expires = DateTime.now().add(Duration(seconds: seconds));
    final batch = _db.batch();
    for (final t in chosen) {
      final offer = _offers.doc();
      batch.set(offer, {
        'jobId': jobId,
        'technicianId': t.id,
        'status': 'pending',
        'expiresAt': Timestamp.fromDate(expires),
        'serviceTitle': job.serviceTitle,
        'approxLocation': job.approxLocation,
        'round': job.dispatchRound,
        'technicianName': t.name,
        'ratingAvg': t.rating,
        'distanceKm': t.km,
        'verified': t.verified,
      });
    }
    batch.update(_jobs.doc(jobId), {
      'status': JobStatus.offerPending.name,
      'expiresAt': Timestamp.fromDate(expires),
    });
    await batch.commit();
  }

  Future<bool> acceptOffer({
    required String offerId,
    required String technicianId,
    required String technicianName,
    required double initialPrice,
  }) async {
    final offerSnap = await _offers.doc(offerId).get();
    if (!offerSnap.exists) return false;
    final jobId = offerSnap.data()?['jobId'] as String?;
    if (jobId == null) return false;
    final jobSnap = await _jobs.doc(jobId).get();
    if (!jobSnap.exists) return false;
    final job = Job.fromDoc(jobSnap);
    if (job.isEmergency) {
      return _winEmergencyOffer(
        offerId: offerId,
        technicianId: technicianId,
        technicianName: technicianName,
        initialPrice: initialPrice,
      );
    }
    return _submitQuote(
      offerId: offerId,
      technicianId: technicianId,
      technicianName: technicianName,
      initialPrice: initialPrice,
    );
  }

  Future<bool> _winEmergencyOffer({
    required String offerId,
    required String technicianId,
    required String technicianName,
    required double initialPrice,
  }) async {
    return _db.runTransaction((tx) async {
      final offerRef = _offers.doc(offerId);
      final offerSnap = await tx.get(offerRef);
      if (!offerSnap.exists) return false;
      final offer = offerSnap.data()!;
      if (offer['technicianId'] != technicianId) return false;
      if (offer['status'] != 'pending') return false;
      final exp = (offer['expiresAt'] as Timestamp?)?.toDate();
      if (exp != null && DateTime.now().isAfter(exp)) {
        tx.update(offerRef, {'status': 'expired'});
        return false;
      }

      final jobRef = _jobs.doc(offer['jobId'] as String);
      final jobSnap = await tx.get(jobRef);
      if (!jobSnap.exists) return false;
      final job = jobSnap.data()!;
      if (job['technicianId'] != null) return false;
      if (job['status'] != JobStatus.offerPending.name &&
          job['status'] != JobStatus.dispatching.name) {
        return false;
      }

      tx.update(jobRef, {
        'technicianId': technicianId,
        'technicianName': technicianName,
        'initialPrice': initialPrice,
        'status': JobStatus.quoted.name,
      });
      tx.update(offerRef, {'status': 'accepted', 'initialPrice': initialPrice});
      return true;
    }).then((won) async {
      if (!won) return false;
      final offerSnap = await _offers.doc(offerId).get();
      final jobId = offerSnap.data()?['jobId'] as String?;
      if (jobId != null) {
        await expireOpenOffers(jobId);
      }
      return true;
    });
  }

  Future<bool> _submitQuote({
    required String offerId,
    required String technicianId,
    required String technicianName,
    required double initialPrice,
  }) async {
    final offerRef = _offers.doc(offerId);
    final ok = await _db.runTransaction((tx) async {
      final offerSnap = await tx.get(offerRef);
      if (!offerSnap.exists) return false;
      final offer = offerSnap.data()!;
      if (offer['technicianId'] != technicianId) return false;
      if (offer['status'] != 'pending') return false;
      final exp = (offer['expiresAt'] as Timestamp?)?.toDate();
      if (exp != null && DateTime.now().isAfter(exp)) {
        tx.update(offerRef, {'status': 'expired'});
        return false;
      }
      final jobRef = _jobs.doc(offer['jobId'] as String);
      final jobSnap = await tx.get(jobRef);
      if (!jobSnap.exists) return false;
      final job = jobSnap.data()!;
      if (job['technicianId'] != null) return false;
      if (job['status'] != JobStatus.offerPending.name) return false;
      tx.update(offerRef, {
        'status': 'submitted',
        'initialPrice': initialPrice,
        'technicianName': technicianName,
      });
      return true;
    });
    if (!ok) return false;
    final jobId = (await offerRef.get()).data()?['jobId'] as String?;
    if (jobId != null) {
      final submitted = await _offers
          .where('jobId', isEqualTo: jobId)
          .where('status', isEqualTo: 'submitted')
          .get();
      if (submitted.docs.length >= AppConstants.maxQuotes) {
        await closeQuoteWindow(jobId);
      }
    }
    return true;
  }

  Future<void> closeQuoteWindow(String jobId) async {
    final snap = await _jobs.doc(jobId).get();
    if (!snap.exists) return;
    final job = Job.fromDoc(snap);
    if (job.technicianId != null) return;
    if (job.status != JobStatus.offerPending) return;
    if (job.isEmergency) return;

    await expireOpenOffers(jobId);
    final submitted = await _offers
        .where('jobId', isEqualTo: jobId)
        .where('status', isEqualTo: 'submitted')
        .get();

    if (submitted.docs.isEmpty) {
      await maybeRedispatch(jobId, expirePending: false);
      return;
    }
    if (submitted.docs.length == 1) {
      final offer = JobOffer.fromDoc(submitted.docs.first);
      await _assignOffer(jobId, offer);
      return;
    }
    await _jobs.doc(jobId).update({'status': JobStatus.comparing.name});
  }

  Future<bool> customerSelectOffer(String jobId, JobOffer offer) async {
    final snap = await _jobs.doc(jobId).get();
    if (!snap.exists) return false;
    final job = Job.fromDoc(snap);
    if (job.technicianId != null) return false;
    if (job.status != JobStatus.comparing && job.status != JobStatus.offerPending) {
      return false;
    }
    if (offer.status != OfferStatus.submitted) return false;
    await _assignOffer(jobId, offer);
    return true;
  }

  Future<void> _assignOffer(String jobId, JobOffer offer) async {
    await _jobs.doc(jobId).update({
      'technicianId': offer.technicianId,
      'technicianName': offer.technicianName ?? 'فني',
      'initialPrice': offer.initialPrice,
      'status': JobStatus.quoted.name,
    });
    await _offers.doc(offer.id).update({'status': 'accepted'});
    final others = await _offers.where('jobId', isEqualTo: jobId).get();
    final batch = _db.batch();
    for (final d in others.docs) {
      if (d.id == offer.id) continue;
      final status = d.data()['status'] as String?;
      if (status == 'submitted' || status == 'pending') {
        batch.update(d.reference, {'status': 'expired'});
      }
    }
    await batch.commit();
  }

  Future<void> rejectOffer(String offerId) {
    return _offers.doc(offerId).update({'status': 'rejected'});
  }

  Future<void> expireOpenOffers(String jobId) async {
    final pending = await _offers
        .where('jobId', isEqualTo: jobId)
        .where('status', isEqualTo: 'pending')
        .get();
    if (pending.docs.isEmpty) return;
    final batch = _db.batch();
    for (final d in pending.docs) {
      batch.update(d.reference, {'status': 'expired'});
    }
    await batch.commit();
  }

  Future<void> onWindowExpired(String jobId) async {
    final snap = await _jobs.doc(jobId).get();
    if (!snap.exists) return;
    final job = Job.fromDoc(snap);
    if (job.status != JobStatus.offerPending) return;
    if (job.isEmergency) {
      await maybeRedispatch(jobId);
      return;
    }
    await closeQuoteWindow(jobId);
  }

  Future<void> maybeRedispatch(String jobId, {bool expirePending = true}) async {
    final snap = await _jobs.doc(jobId).get();
    if (!snap.exists) return;
    final job = Job.fromDoc(snap);
    if (job.status != JobStatus.offerPending &&
        job.status != JobStatus.dispatching &&
        job.status != JobStatus.noTechnician) {
      return;
    }
    if (job.technicianId != null) return;
    if (expirePending) await expireOpenOffers(jobId);
    if (job.status == JobStatus.noTechnician) {
      await _jobs.doc(jobId).update({
        'dispatchRound': 1,
        'status': JobStatus.dispatching.name,
      });
      await dispatch(jobId);
      return;
    }
    if (job.dispatchRound >= AppConstants.maxDispatchRounds &&
        job.status != JobStatus.dispatching) {
      await _jobs.doc(jobId).update({'status': JobStatus.noTechnician.name});
      return;
    }
    final nextRound =
        job.status == JobStatus.dispatching ? job.dispatchRound : job.dispatchRound + 1;
    if (nextRound > AppConstants.maxDispatchRounds) {
      await _jobs.doc(jobId).update({'status': JobStatus.noTechnician.name});
      return;
    }
    await _jobs.doc(jobId).update({
      'dispatchRound': nextRound,
      'status': JobStatus.dispatching.name,
    });
    await dispatch(jobId);
  }

  Future<void> customerAcceptQuote(String jobId) async {
    final loc = await _db.collection('jobLocations').doc(jobId).get();
    final exact = loc.data()?['exact'] as GeoPoint?;
    await _jobs.doc(jobId).update({
      'status': JobStatus.enRoute.name,
      if (exact != null) 'exactLocation': exact,
    });
  }

  Future<void> customerRejectQuote(String jobId) async {
    await expireOpenOffers(jobId);
    await _jobs.doc(jobId).update({
      'status': JobStatus.cancelled.name,
      'technicianId': null,
    });
  }

  Future<void> markArrived(String jobId) {
    return _jobs.doc(jobId).update({'status': JobStatus.arrived.name});
  }

  Future<void> submitFinalQuote({
    required String jobId,
    required double finalPrice,
    required Warranty warranty,
  }) {
    return _jobs.doc(jobId).update({
      'finalPrice': finalPrice,
      'warranty': warranty.toMap(),
      'status': JobStatus.finalQuote.name,
    });
  }

  Future<void> customerAcceptFinal(String jobId) {
    return _jobs.doc(jobId).update({'status': JobStatus.inProgress.name});
  }

  Future<void> completeJob({
    required String jobId,
    required double receivedAmount,
    required bool warrantyEnabled,
  }) async {
    final commission = (receivedAmount * AppConstants.commissionRate * 100).round() / 100;
    await _db.runTransaction((tx) async {
      final jobRef = _jobs.doc(jobId);
      final jobSnap = await tx.get(jobRef);
      if (!jobSnap.exists) return;
      final job = jobSnap.data()!;
      final techId = job['technicianId'] as String?;
      tx.update(jobRef, {
        'receivedAmount': receivedAmount,
        'commissionAmount': commission,
        'status': JobStatus.completed.name,
        'warranty.startsAt': warrantyEnabled ? Timestamp.fromDate(DateTime.now()) : null,
      });
      if (techId == null) return;
      final techRef = _db.collection(Cols.users).doc(techId);
      final techSnap = await tx.get(techRef);
      final data = techSnap.data() ?? {};
      final wallet = (data['walletBalance'] as num?)?.toDouble() ?? 0;
      final next = wallet - commission;
      tx.update(techRef, {
        'walletBalance': next,
        if (next < AppConstants.minWalletBalance) 'isOnline': false,
      });
    });
  }

  Future<void> rateAsCustomer(String jobId, int stars) {
    return _jobs.doc(jobId).update({
      'ratings.customerToTech': stars,
    });
  }

  Future<void> rateAsTechnician(String jobId, int stars) {
    return _jobs.doc(jobId).update({
      'ratings.techToCustomer': stars,
    });
  }

  Future<void> markRatedIfDone(String jobId) async {
    final snap = await _jobs.doc(jobId).get();
    if (!snap.exists) return;
    final job = Job.fromDoc(snap);
    if (job.ratings.bothDone) {
      await _jobs.doc(jobId).update({'status': JobStatus.rated.name});
    }
  }
}
