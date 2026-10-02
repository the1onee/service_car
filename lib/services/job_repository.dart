import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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

  Stream<List<JobOffer>> watchPendingOffers(String technicianId) {
    return _offers
        .where('technicianId', isEqualTo: technicianId)
        .where('status', isEqualTo: 'pending')
        .limit(20)
        .snapshots()
        .map((s) => s.docs.map(JobOffer.fromDoc).toList());
  }

  Stream<List<JobOffer>> watchSubmittedOffers(String technicianId) {
    return _offers
        .where('technicianId', isEqualTo: technicianId)
        .where('status', isEqualTo: 'submitted')
        .limit(20)
        .snapshots()
        .map((s) => s.docs.map(JobOffer.fromDoc).toList());
  }

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

  Stream<List<Job>> watchRecentForCustomer(String uid) {
    return _jobs
        .where('customerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((s) => s.docs.map(Job.fromDoc).toList());
  }

  Stream<List<Job>> watchRecentForTechnician(String uid) {
    return _jobs
        .where('technicianId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((s) => s.docs.map(Job.fromDoc).toList());
  }

  Stream<List<JobOffer>> watchJobQuotes(String jobId) {
    return _offers
        .where('jobId', isEqualTo: jobId)
        .limit(40)
        .snapshots()
        .map((s) {
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
    };
    for (final d in snap.docs) {
      final job = Job.fromDoc(d);
      if (active.contains(job.status)) return job;
    }
    return null;
  }

  Future<String> createJob({
    required String customerId,
    required String serviceId,
    required String serviceTitle,
    required GeoPoint exact,
    String? vehicleTypeId,
    String? vehicleTypeTitle,
    bool? isEmergency,
    double? commissionRate,
    String partName = '',
    String partNote = '',
    String partImageUrl = '',
    String carMake = '',
    String carModel = '',
    String carYear = '',
    String customerPhone = '',
    String deliveryAddress = '',
    String providerKind = '',
    String specialtyId = '',
    String specialtyAr = '',
    GeoPoint? dropoff,
    String dropoffLabel = '',
  }) async {
    final ref = _jobs.doc();
    final toWorkshops =
        providerKind == 'workshop' || serviceId == 'parts';
    final toOilWorkshops =
        providerKind == 'oilWorkshop' || serviceId == 'oil';
    final toPaintShops = providerKind == 'paintShop' ||
        providerKind == 'paint_shop' ||
        serviceId == 'paint';
    final emergency = (toWorkshops || toOilWorkshops || toPaintShops)
        ? false
        : (isEmergency ?? isEmergencyService(serviceId));
    final rate = (commissionRate ?? AppConstants.commissionRate).clamp(0.0, 1.0);
    final resolvedKind = toWorkshops
        ? 'workshop'
        : (toOilWorkshops
            ? 'oilWorkshop'
            : (toPaintShops ? 'paintShop' : providerKind));
    final job = Job(
      id: ref.id,
      customerId: customerId,
      serviceId: serviceId,
      serviceTitle: serviceTitle,
      vehicleTypeId: vehicleTypeId,
      vehicleTypeTitle: vehicleTypeTitle,
      status: JobStatus.dispatching,
      matchingMode: emergency ? MatchingMode.emergency : MatchingMode.quotes,
      commissionRate: rate,
      approxLocation: approximate(exact),
      createdAt: DateTime.now(),
      partName: partName,
      partNote: partNote,
      partImageUrl: partImageUrl,
      carMake: carMake,
      carModel: carModel,
      carYear: carYear,
      customerPhone: customerPhone,
      providerKind: resolvedKind,
      specialtyId: specialtyId.trim(),
      specialtyAr: specialtyAr.trim(),
    );
    final batch = _db.batch();
    batch.set(ref, job.toCreateMap());
    final locPayload = <String, dynamic>{
      'customerId': customerId,
      'exact': exact,
      if (deliveryAddress.trim().isNotEmpty) 'label': deliveryAddress.trim(),
    };
    if (dropoff != null) {
      locPayload['dropoff'] = dropoff;
      if (dropoffLabel.trim().isNotEmpty) {
        locPayload['dropoffLabel'] = dropoffLabel.trim();
      }
    }
    batch.set(_db.collection('jobLocations').doc(ref.id), locPayload);
    await batch.commit();
    return ref.id;
  }

  Future<void> dispatch(String jobId) async {
    final jobSnap = await _jobs.doc(jobId).get();
    if (!jobSnap.exists) return;
    final job = Job.fromDoc(jobSnap);
    if (job.technicianId != null) return;
    if (job.status != JobStatus.dispatching &&
        job.status != JobStatus.offerPending &&
        job.status != JobStatus.noTechnician) {
      return;
    }

    final providerRole = job.isPartsOrder
        ? 'workshop'
        : (job.isOilOrder
            ? 'oilWorkshop'
            : (job.isPaintOrder ? 'paintShop' : 'technician'));
    // استعلام role فقط (متوافق مع قواعد القراءة). التصفية بالمعتمد محلياً.
    QuerySnapshot<Map<String, dynamic>> techsSnap;
    try {
      techsSnap = await _db
          .collection(Cols.users)
          .where('role', isEqualTo: providerRole)
          .get();
    } catch (e) {
      // لا نترك الطلب معلّقاً على dispatching.
      await _jobs.doc(jobId).update({'status': JobStatus.noTechnician.name});
      rethrow;
    }
    final techs = techsSnap;

    final previous = await _offers.where('jobId', isEqualTo: jobId).get();
    final now = DateTime.now();
    final livePending = previous.docs.where((d) {
      final data = d.data();
      if (data['status'] != 'pending') return false;
      final exp = (data['expiresAt'] as Timestamp?)?.toDate();
      return exp == null || exp.isAfter(now);
    }).toList();
    if (livePending.isNotEmpty) {
      if (job.status != JobStatus.offerPending) {
        await _jobs.doc(jobId).update({'status': JobStatus.offerPending.name});
      }
      return;
    }
    final used = previous.docs.map((d) => d.data()['technicianId'] as String?).toSet();
    final settingsSnap = await _db.collection(Cols.appSettings).doc('main').get();
    final minWallet =
        (settingsSnap.data()?['minWalletBalance'] as num?)?.toDouble() ??
            AppConstants.minWalletBalance;

    final candidates = techs.docs
        .map((d) {
          final data = d.data();
          final geo = data['geo'] as GeoPoint?;
          final km = geo == null
              ? 0.0 // بلا موقع: لا نستبعد ورش القطع بسبب المسافة
              : haversineKm(
                  job.approxLocation.latitude,
                  job.approxLocation.longitude,
                  geo.latitude,
                  geo.longitude,
                );
          final serviceIds = List<String>.from(
            data['serviceIds'] as List? ?? const [],
          );
          final vehicleTypeIds = List<String>.from(
            data['vehicleTypeIds'] as List? ?? const [],
          );
          final role = data['role'] as String? ?? '';
          final defaultName = switch (role) {
            'workshop' => 'ورشة',
            'oilWorkshop' => 'ورشة زيوت',
            'paintShop' => 'ورشة دهان',
            _ => 'فني',
          };
          return (
            id: d.id,
            online: data['isOnline'] == true,
            km: km,
            token: data['fcmToken'] as String?,
            name: data['name'] as String? ?? defaultName,
            rating: (data['ratingAvg'] as num?)?.toDouble() ?? 5,
            verified: data['verified'] == true ||
                data['verificationStatus'] == 'approved',
            wallet: (data['walletBalance'] as num?)?.toDouble() ?? 0,
            serviceIds: serviceIds,
            vehicleTypeIds: vehicleTypeIds,
            isWorkshop: role == 'workshop' || role == 'paintShop',
            oilWorkshopTier: data['oilWorkshopTier'] as String? ?? '',
            specialtyId: data['specialtyId'] as String? ?? '',
            specialtyAr: data['specialtyAr'] as String? ?? '',
          );
        })
        .where((t) {
          // طلبات القطع تصل لكل ورش التخصص دون شرط متاح/غير متاح.
          if (job.isPartsOrder) return true;
          return t.online;
        })
        .where((t) => t.verified)
        .where((t) {
          // ورش القطع ترى الطلبات حتى مع رصيد منخفض؛ القفل عند التسعير فقط.
          if (job.isPartsOrder) return true;
          return t.isWorkshop || t.wallet >= minWallet;
        })
        .where((t) => !used.contains(t.id))
        .where((t) {
          // ورش القطع لا تُفلتر بـ serviceIds (غالباً غير مضبوطة).
          if (t.isWorkshop && job.isPartsOrder) return true;
          return t.serviceIds.isEmpty || t.serviceIds.contains(job.serviceId);
        })
        .where((t) {
          final maxKm = job.isPartsOrder
              ? AppConstants.maxPartsMatchKm
              : AppConstants.maxMatchKm;
          return t.km <= maxKm;
        })
        .where((t) {
          if (t.isWorkshop) return true;
          final needed = job.vehicleTypeId;
          if (needed == null || needed.isEmpty) return true;
          if (t.vehicleTypeIds.isEmpty) return true;
          return t.vehicleTypeIds.contains(needed);
        })
        .toList();

    // قطع الغيار: تطابق اختصاص صارم فقط (بدون توسيع لكل الورش).
    var ranked = candidates.where((t) {
      if (job.isPartsOrder && job.specialtyId.isNotEmpty) {
        return t.specialtyId == job.specialtyId;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.km.compareTo(b.km));

    final take = job.isPartsOrder
        ? ranked.length
        : (job.isEmergency
            ? AppConstants.emergencyTechsPerRound
            : AppConstants.quoteTechsPerRound);
    final chosen = ranked.take(take).toList();
    if (chosen.isEmpty) {
      await _jobs.doc(jobId).update({'status': JobStatus.noTechnician.name});
      return;
    }

    final noExpiry = job.isPartsOrder;
    final seconds = job.isEmergency
        ? AppConstants.emergencyOfferSeconds
        : AppConstants.quoteWindowSeconds;
    final expires =
        noExpiry ? null : DateTime.now().add(Duration(seconds: seconds));
    final batch = _db.batch();
    for (final t in chosen) {
      final offer = _offers.doc();
      batch.set(offer, {
        'jobId': jobId,
        'technicianId': t.id,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        if (expires != null) 'expiresAt': Timestamp.fromDate(expires),
        'serviceTitle': job.serviceTitle,
        'vehicleTypeTitle': job.vehicleTypeTitle,
        'approxLocation': job.approxLocation,
        'round': job.dispatchRound,
        'technicianName': t.name,
        'ratingAvg': t.rating,
        'distanceKm': t.km,
        'verified': t.verified,
        'partName': job.partName,
        'carMake': job.carMake,
        'carModel': job.carModel,
        'providerKind': job.providerKind,
        'specialtyAr':
            t.specialtyAr.isNotEmpty ? t.specialtyAr : job.specialtyAr,
        if (job.partImageUrl.isNotEmpty) 'partImageUrl': job.partImageUrl,
        if (t.oilWorkshopTier.isNotEmpty)
          'oilWorkshopTier': t.oilWorkshopTier,
      });
    }
    batch.update(_jobs.doc(jobId), {
      'status': JobStatus.offerPending.name,
      if (expires != null) 'expiresAt': Timestamp.fromDate(expires),
      if (noExpiry) 'expiresAt': FieldValue.delete(),
    });
    await batch.commit();
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
    final amountError = AppConstants.serviceAmountError(initialPrice);
    if (amountError != null) throw StateError(amountError);
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
      partCondition: partCondition,
      warrantyDays: warrantyDays,
      warrantyNote: warrantyNote,
      deliveryType: deliveryType,
      vendorNote: vendorNote,
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
          job['status'] != JobStatus.dispatching.name &&
          job['status'] != JobStatus.noTechnician.name) {
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
    String partCondition = '',
    int warrantyDays = 0,
    String warrantyNote = '',
    String deliveryType = '',
    String vendorNote = '',
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
      if (job['status'] != JobStatus.offerPending.name &&
          job['status'] != JobStatus.dispatching.name &&
          job['status'] != JobStatus.noTechnician.name) {
        return false;
      }
      tx.update(offerRef, {
        'status': 'submitted',
        'initialPrice': initialPrice,
        'technicianName': technicianName,
        if (partCondition.isNotEmpty) 'partCondition': partCondition,
        if (warrantyDays > 0) 'warrantyDays': warrantyDays,
        if (warrantyNote.isNotEmpty) 'warrantyNote': warrantyNote,
        if (deliveryType.isNotEmpty) 'deliveryType': deliveryType,
        if (vendorNote.isNotEmpty) 'vendorNote': vendorNote,
      });
      return true;
    });
    if (!ok) return false;
    // لا نستعلم عن كل عروض الطلب هنا: المزود لا يقرأ عروض الورش الأخرى
    // وفق القواعد → permission-denied بعد نجاح الإرسال. إغلاق النافذة عبر CF/العميل.
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
    final warrantyDays = offer.warrantyDays;
    final warrantyNote = offer.warrantyNote;
    final jobSnap = await _jobs.doc(jobId).get();
    final isParts = jobSnap.exists && Job.fromDoc(jobSnap).isPartsOrder;
    final price = offer.initialPrice;
    GeoPoint? exact;
    var deliveryAddress = '';
    if (isParts) {
      final loc = await _db.collection('jobLocations').doc(jobId).get();
      final data = loc.data();
      exact = data?['exact'] as GeoPoint?;
      deliveryAddress = (data?['label'] as String? ?? '').trim();
    }
    // قطع الغيار: القبول يُسند الطلب مباشرة للورشة للتجهيز (بدون موافقة سعر أولي/نهائي).
    await _jobs.doc(jobId).update({
      'technicianId': offer.technicianId,
      'technicianName': offer.technicianName ?? 'فني',
      'initialPrice': price,
      if (isParts && price != null) 'finalPrice': price,
      'status': isParts ? JobStatus.enRoute.name : JobStatus.quoted.name,
      if (exact != null) 'exactLocation': exact,
      if (deliveryAddress.isNotEmpty) 'deliveryAddress': deliveryAddress,
      if (offer.partCondition.isNotEmpty) 'partCondition': offer.partCondition,
      if (offer.deliveryType.isNotEmpty) 'deliveryType': offer.deliveryType,
      if (offer.vendorNote.isNotEmpty) 'vendorNote': offer.vendorNote,
      if (warrantyDays > 0)
        'warranty': Warranty(
          enabled: true,
          type: WarrantyType.part,
          days: warrantyDays,
          note: warrantyNote.isEmpty ? 'ضمان $warrantyDays يوم' : warrantyNote,
        ).toMap(),
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
    // طلبات القطع تبقى مفتوحة حتى القبول أو الإلغاء — بلا نافذة زمنية.
    if (job.isPartsOrder) return;
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

  Future<void> customerRejectQuote(String jobId) {
    return customerCancelJob(jobId);
  }

  Future<void> customerCancelJob(String jobId, {String reason = ''}) async {
    final snap = await _jobs.doc(jobId).get();
    if (!snap.exists) return;
    final job = Job.fromDoc(snap);
    if (!job.customerCanCancel) {
      throw StateError('لا يمكن إلغاء الطلب بعد بدء العمل');
    }
    await expireOpenOffers(jobId);
    await _jobs.doc(jobId).update({
      'status': JobStatus.cancelled.name,
      'technicianId': null,
      'technicianName': null,
      'cancelledBy': 'customer',
      'cancelReason': reason.trim(),
    });
  }

  Future<void> technicianWithdraw(String jobId, {String reason = ''}) async {
    final snap = await _jobs.doc(jobId).get();
    if (!snap.exists) return;
    final job = Job.fromDoc(snap);
    if (!job.technicianCanWithdraw) {
      throw StateError('لا يمكن الانسحاب بعد بدء العمل');
    }
    await expireOpenOffers(jobId);
    await _jobs.doc(jobId).update({
      'status': JobStatus.dispatching.name,
      'technicianId': null,
      'technicianName': null,
      'cancelledBy': 'technician',
      'cancelReason': reason.trim(),
      'exactLocation': null,
    });
  }

  /// إلغاء نهائي لطلب قطع من الورشة المعيّنة.
  Future<void> workshopCancelJob(String jobId, {String reason = ''}) async {
    final snap = await _jobs.doc(jobId).get();
    if (!snap.exists) return;
    final job = Job.fromDoc(snap);
    if (!job.isPartsOrder) {
      throw StateError('الإلغاء متاح لطلبات القطع فقط');
    }
    if (!job.technicianCanWithdraw) {
      throw StateError('لا يمكن إلغاء الطلب بعد بدء التنفيذ');
    }
    await expireOpenOffers(jobId);
    await _jobs.doc(jobId).update({
      'status': JobStatus.cancelled.name,
      'technicianId': null,
      'technicianName': null,
      'cancelledBy': 'workshop',
      'cancelReason': reason.trim(),
      'exactLocation': null,
    });
  }

  Future<void> setUseWallet({
    required String jobId,
    required bool use,
    required double reserve,
  }) {
    return _jobs.doc(jobId).update({
      'useWallet': use,
      'walletReserve': use ? reserve : 0,
    });
  }

  Future<void> markArrived(String jobId) {
    return _jobs.doc(jobId).update({'status': JobStatus.arrived.name});
  }

  /// ورشة قطع الغيار: تأكيد تجهيز/إرسال القطعة للعميل.
  Future<void> markPartsShipped(String jobId) async {
    // إن بقي الطلب على quoted من CF القديمة، رقِّه أولاً.
    await promotePartsQuotedToEnRoute(jobId);
    await _jobs.doc(jobId).update({'status': JobStatus.inProgress.name});
  }

  /// ترحيل طلبات القطع العالقة على quoted بعد قبول العميل → enRoute.
  Future<void> promotePartsQuotedToEnRoute(String jobId) async {
    final snap = await _jobs.doc(jobId).get();
    if (!snap.exists) return;
    final job = Job.fromDoc(snap);
    if (!job.isPartsOrder) return;
    if (job.status != JobStatus.quoted) return;
    if (job.technicianId == null) return;
    await _jobs.doc(jobId).update({
      'status': JobStatus.enRoute.name,
      if (job.finalPrice == null && job.initialPrice != null)
        'finalPrice': job.initialPrice,
    });
  }

  /// العميل يؤكد استلام القطعة، وتُخصم نسبة الورشة المسجّلة على حسابها.
  Future<void> customerConfirmPartsReceived(String jobId) async {
    final jobRef = _jobs.doc(jobId);
    final entryRef = _db.collection(Cols.walletEntries).doc('commission_$jobId');
    await _db.runTransaction((tx) async {
      final jobSnap = await tx.get(jobRef);
      if (!jobSnap.exists) return;
      final job = Job.fromDoc(jobSnap);
      if (!job.isPartsOrder) {
        throw StateError('تأكيد الاستلام متاح لطلبات القطع فقط');
      }
      if (job.status == JobStatus.completed || job.status == JobStatus.rated) {
        return;
      }
      if (job.status != JobStatus.inProgress &&
          job.status != JobStatus.arrived &&
          job.status != JobStatus.finalQuote) {
        throw StateError('الطلب ليس جاهزاً للاستلام بعد');
      }
      final techId = job.technicianId;
      if (techId == null || techId.isEmpty) {
        throw StateError('لا توجد ورشة معيّنة');
      }
      final techRef = _db.collection(Cols.users).doc(techId);
      final techSnap = await tx.get(techRef);
      final entrySnap = await tx.get(entryRef);
      final percent =
          (techSnap.data()?['commissionPercent'] as num?)?.toDouble() ?? 0;
      final rate = (percent / 100).clamp(0.0, 1.0);
      final amount = job.billAmount;
      final commission = _money(amount * rate);
      tx.update(jobRef, {
        'status': JobStatus.completed.name,
        'receivedAmount': amount,
        if (job.finalPrice == null && job.initialPrice != null)
          'finalPrice': job.initialPrice,
        'commissionAmount': commission,
        'commissionRate': rate,
        if (job.warranty.enabled)
          'warranty.startsAt': Timestamp.fromDate(DateTime.now()),
      });
      if (commission <= 0 || entrySnap.exists) return;
      final wallet = (techSnap.data()?['walletBalance'] as num?)?.toDouble() ?? 0;
      final next = wallet - commission;
      tx.set(entryRef, {
        'userId': techId,
        'type': 'commission',
        'amount': commission,
        'signedAmount': -commission,
        'balanceAfter': next,
        'jobId': jobId,
        'note': 'عمولة قطعة الغيار',
        'createdBy': job.customerId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(techRef, {
        'walletBalance': next,
        'walletJobId': jobId,
      });
    });
  }

  Future<void> submitFinalQuote({
    required String jobId,
    required double finalPrice,
    required Warranty warranty,
  }) {
    final amountError = AppConstants.serviceAmountError(finalPrice);
    if (amountError != null) throw StateError(amountError);
    return _jobs.doc(jobId).update({
      'finalPrice': finalPrice,
      'warranty': warranty.toMap(),
      'status': JobStatus.finalQuote.name,
    });
  }

  Future<void> customerAcceptFinal(String jobId) {
    return _jobs.doc(jobId).update({'status': JobStatus.inProgress.name});
  }

  var _completeOnServer = false;

  Future<void> completeJob({
    required String jobId,
    required double receivedAmount,
    required bool warrantyEnabled,
  }) async {
    if (_completeOnServer) {
      try {
        await FirebaseFunctions.instance.httpsCallable('completeJob').call({
          'jobId': jobId,
          'receivedAmount': receivedAmount,
          'warrantyEnabled': warrantyEnabled,
        });
        return;
      } on FirebaseFunctionsException catch (e) {
        const fallback = {
          'not-found',
          'unavailable',
          'unimplemented',
          'deadline-exceeded',
          'internal',
        };
        if (!fallback.contains(e.code)) rethrow;
        _completeOnServer = false;
      }
    }
    await _completeJobLocal(
      jobId: jobId,
      receivedAmount: receivedAmount,
      warrantyEnabled: warrantyEnabled,
    );
  }

  Future<void> _completeJobLocal({
    required String jobId,
    required double receivedAmount,
    required bool warrantyEnabled,
  }) async {
    final jobRef = _jobs.doc(jobId);
    final entryRef = _db.collection(Cols.walletEntries).doc('commission_$jobId');
    var customerId = '';
    var useWallet = false;
    var bill = 0.0;
    await _db.runTransaction((tx) async {
      final jobSnap = await tx.get(jobRef);
      if (!jobSnap.exists) return;
      final job = jobSnap.data()!;
      final techId = job['technicianId'] as String?;
      if (techId == null) return;
      customerId = job['customerId'] as String? ?? '';
      useWallet = job['useWallet'] == true;
      bill = _billOf(job, receivedAmount);
      final entrySnap = await tx.get(entryRef);
      final techRef = _db.collection(Cols.users).doc(techId);
      final techSnap = await tx.get(techRef);
      final settingsSnap = await tx.get(_db.collection(Cols.appSettings).doc('main'));
      final min = (settingsSnap.data()?['minWalletBalance'] as num?)?.toDouble() ??
          AppConstants.minWalletBalance;
      final rateRaw = job['commissionRate'];
      final rate = rateRaw is num
          ? rateRaw.toDouble().clamp(0.0, 1.0)
          : AppConstants.commissionRate;
      final commission = (bill * rate * 100).round() / 100;
      final status = job['status'] as String?;
      if (entrySnap.exists || status == JobStatus.completed.name) {
        if (status != JobStatus.completed.name) {
          tx.update(jobRef, {
            'receivedAmount': _money(receivedAmount),
            'commissionAmount': commission,
            'status': JobStatus.completed.name,
          });
        }
        return;
      }
      final wallet = (techSnap.data()?['walletBalance'] as num?)?.toDouble() ?? 0;
      final next = _money(wallet - commission);
      final now = FieldValue.serverTimestamp();
      tx.update(jobRef, {
        'receivedAmount': _money(receivedAmount),
        'commissionAmount': commission,
        'status': JobStatus.completed.name,
        if (warrantyEnabled) 'warranty.startsAt': Timestamp.fromDate(DateTime.now()),
      });
      tx.set(entryRef, {
        'userId': techId,
        'type': 'commission',
        'amount': commission,
        'signedAmount': -commission,
        'balanceAfter': next,
        'jobId': jobId,
        'note': 'عمولة إكمال الطلب',
        'createdBy': techId,
        'createdAt': now,
      });
      tx.update(techRef, {
        'walletBalance': next,
        if (next < min) 'isOnline': false,
      });
    });
    if (customerId.isEmpty || (!useWallet && receivedAmount <= bill)) return;
    await _settleCustomerChange(
      jobId: jobId,
      customerId: customerId,
      bill: bill,
      receivedAmount: receivedAmount,
      useWallet: useWallet,
    );
  }

  Future<void> _settleCustomerChange({
    required String jobId,
    required String customerId,
    required double bill,
    required double receivedAmount,
    required bool useWallet,
  }) async {
    final jobRef = _jobs.doc(jobId);
    final spendRef = _db.collection(Cols.walletEntries).doc('spend_$jobId');
    final changeRef = _db.collection(Cols.walletEntries).doc('change_$jobId');
    final customerRef = _db.collection(Cols.users).doc(customerId);
    await _db.runTransaction((tx) async {
      final customerSnap = await tx.get(customerRef);
      final spendSnap = await tx.get(spendRef);
      final changeSnap = await tx.get(changeRef);
      if (!customerSnap.exists) return;
      final custBal = (customerSnap.data()?['walletBalance'] as num?)?.toDouble() ?? 0;
      final applied = useWallet
          ? _money(custBal < bill ? (custBal < 0 ? 0 : custBal) : bill)
          : 0.0;
      final cashDue = _money(bill - applied < 0 ? 0 : bill - applied);
      final change = _money(receivedAmount - cashDue < 0 ? 0 : receivedAmount - cashDue);
      if (applied <= 0 && change <= 0) return;
      final custNext = _money(custBal - applied + change);
      final now = FieldValue.serverTimestamp();
      if (applied > 0 && !spendSnap.exists) {
        tx.set(spendRef, {
          'userId': customerId,
          'type': 'spend',
          'amount': applied,
          'signedAmount': -applied,
          'balanceAfter': _money(custBal - applied),
          'jobId': jobId,
          'note': 'خصم رصيد على الطلب',
          'createdBy': customerId,
          'createdAt': now,
        });
      }
      if (change > 0 && !changeSnap.exists) {
        tx.set(changeRef, {
          'userId': customerId,
          'type': 'change',
          'amount': change,
          'signedAmount': change,
          'balanceAfter': custNext,
          'jobId': jobId,
          'note': 'باقي دفعة الطلب',
          'createdBy': customerId,
          'createdAt': now,
        });
      }
      tx.update(customerRef, {
        'walletBalance': custNext,
        'walletJobId': jobId,
      });
      tx.update(jobRef, {
        'walletApplied': applied,
        'changeAmount': change,
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

  double _money(num value) => (value * 100).round() / 100;

  double _billOf(Map<String, dynamic> job, double received) {
    final finalPrice = (job['finalPrice'] as num?)?.toDouble();
    if (finalPrice != null && finalPrice > 0) return _money(finalPrice);
    final initial = (job['initialPrice'] as num?)?.toDouble();
    if (initial != null && initial > 0) return _money(initial);
    return _money(received);
  }
}
