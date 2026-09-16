import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barrr/core/constants.dart';
import 'package:barrr/core/geo.dart';
import 'package:barrr/data/service_catalog.dart';
import 'package:barrr/demo/demo_mode.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/job.dart';
import 'package:barrr/models/job_offer.dart';
import 'package:barrr/models/service_item.dart';
import 'package:barrr/models/warranty.dart';

class DemoStore {
  DemoStore._() {
    _seed();
  }

  static final DemoStore instance = DemoStore._();

  String? currentUid;
  final _auth = StreamController<String?>.broadcast();
  final _bus = StreamController<int>.broadcast();
  int _n = 0;
  int _ids = 100;

  final Map<String, String> passwords = {};
  final Map<String, AppUser> users = {};
  final Map<String, Job> jobs = {};
  final Map<String, JobOffer> offers = {};
  final Map<String, GeoPoint> exactLocations = {};

  Stream<String?> get uidStream async* {
    yield currentUid;
    yield* _auth.stream;
  }

  Stream<T> map<T>(T Function() read) async* {
    yield read();
    await for (final _ in _bus.stream) {
      yield read();
    }
  }

  void notify() => _bus.add(++_n);

  String _id(String p) => '$p${_ids++}';

  void _seed() {
    final services = seedServices.map((s) => s.id).toList();
    _putUser(
      const AppUser(
        id: 'cust1',
        role: UserRole.customer,
        name: 'علي البصري',
        phone: '07700000001',
        email: DemoAccounts.customerEmail,
        verificationStatus: VerificationStatus.approved,
        verified: true,
      ),
    );
    _putUser(
      AppUser(
        id: 'tech1',
        role: UserRole.technician,
        name: 'حسين الميكانيكي',
        phone: '07700000002',
        email: DemoAccounts.techEmail,
        ratingAvg: 4.8,
        ratingCount: 24,
        isOnline: true,
        verified: true,
        verificationStatus: VerificationStatus.approved,
        walletBalance: 50000,
        serviceIds: services,
        geo: const GeoPoint(AppConstants.defaultLat, AppConstants.defaultLng),
      ),
    );
    _putUser(
      AppUser(
        id: 'tech2',
        role: UserRole.technician,
        name: 'محمد الإطارات',
        phone: '07700000003',
        email: DemoAccounts.tech2Email,
        ratingAvg: 4.5,
        ratingCount: 11,
        isOnline: true,
        verified: true,
        verificationStatus: VerificationStatus.approved,
        walletBalance: 40000,
        serviceIds: services,
        geo: const GeoPoint(AppConstants.defaultLat + 0.012, AppConstants.defaultLng + 0.01),
      ),
    );
    _putUser(
      const AppUser(
        id: 'admin1',
        role: UserRole.admin,
        name: 'إدارة التطبيق',
        phone: '07700000000',
        email: DemoAccounts.adminEmail,
        verificationStatus: VerificationStatus.approved,
        verified: true,
      ),
    );
  }

  void _putUser(AppUser user) {
    users[user.id] = user;
    passwords[user.email.toLowerCase()] = DemoAccounts.password;
  }

  Future<void> signIn(String email, String password) async {
    final key = email.trim().toLowerCase();
    AppUser? user;
    for (final u in users.values) {
      if (u.email.toLowerCase() == key) {
        user = u;
        break;
      }
    }
    if (user == null || passwords[key] != password.trim()) {
      throw StateError('bad credentials');
    }
    currentUid = user.id;
    _auth.add(currentUid);
    notify();
  }

  Future<void> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required UserRole role,
    List<String> serviceIds = const [],
  }) async {
    final key = email.trim().toLowerCase();
    if (users.values.any((u) => u.email.toLowerCase() == key)) {
      throw StateError('exists');
    }
    final id = _id('u');
    final isTech = role == UserRole.technician;
    users[id] = AppUser(
      id: id,
      role: role,
      name: name.trim(),
      phone: phone.trim(),
      email: email.trim(),
      serviceIds: isTech ? serviceIds : const [],
      verified: !isTech,
      verificationStatus:
          isTech ? VerificationStatus.pending : VerificationStatus.approved,
    );
    passwords[key] = password.trim();
    currentUid = id;
    _auth.add(currentUid);
    notify();
  }

  Future<void> signOut() async {
    currentUid = null;
    _auth.add(null);
    notify();
  }

  AppUser? user(String uid) => users[uid];

  List<AppUser> technicians() =>
      users.values.where((u) => u.role == UserRole.technician).toList();

  List<ServiceItem> services() => seedServices;

  Future<void> setOnline(String uid, bool online) async {
    final u = users[uid];
    if (u == null) return;
    if (online && !u.canReceiveJobs) return;
    users[uid] = u.copyWith(isOnline: online);
    notify();
  }

  Future<void> setGeo(String uid, GeoPoint geo) async {
    final u = users[uid];
    if (u == null) return;
    users[uid] = u.copyWith(geo: geo);
    notify();
  }

  Future<void> setServiceIds(String uid, List<String> ids) async {
    final u = users[uid];
    if (u == null) return;
    users[uid] = u.copyWith(serviceIds: ids);
    notify();
  }

  Future<void> topUpWallet(String uid, double amount) async {
    final u = users[uid];
    if (u == null || amount <= 0) return;
    users[uid] = u.copyWith(walletBalance: u.walletBalance + amount);
    notify();
  }

  Future<void> setVerification({required String uid, required bool approved}) async {
    final u = users[uid];
    if (u == null) return;
    users[uid] = u.copyWith(
      verified: approved,
      verificationStatus: approved ? VerificationStatus.approved : VerificationStatus.rejected,
      isOnline: approved ? u.isOnline : false,
    );
    notify();
  }

  Future<void> applyRating(String uid, int stars) async {
    final u = users[uid];
    if (u == null) return;
    final nextCount = u.ratingCount + 1;
    final nextAvg = ((u.ratingAvg * u.ratingCount) + stars) / nextCount;
    users[uid] = AppUser(
      id: u.id,
      role: u.role,
      name: u.name,
      phone: u.phone,
      email: u.email,
      ratingAvg: nextAvg,
      ratingCount: nextCount,
      fcmToken: u.fcmToken,
      isOnline: u.isOnline,
      geo: u.geo,
      serviceIds: u.serviceIds,
      verified: u.verified,
      verificationStatus: u.verificationStatus,
      walletBalance: u.walletBalance,
    );
    notify();
  }

  Job? _firstActive(Iterable<Job> list) {
    const active = {
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
    final sorted = list.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final job in sorted) {
      if (!active.contains(job.status)) continue;
      if (job.status == JobStatus.completed && job.ratings.bothDone) continue;
      return job;
    }
    return null;
  }

  Job? activeForCustomer(String uid) =>
      _firstActive(jobs.values.where((j) => j.customerId == uid));

  Job? activeForTechnician(String uid) =>
      _firstActive(jobs.values.where((j) => j.technicianId == uid));

  List<JobOffer> pendingOffers(String technicianId) => offers.values
      .where((o) => o.technicianId == technicianId && o.status == OfferStatus.pending)
      .toList();

  List<JobOffer> quotesFor(String jobId) {
    final list = offers.values
        .where((o) =>
            o.jobId == jobId &&
            (o.status == OfferStatus.submitted || o.status == OfferStatus.accepted))
        .toList()
      ..sort((a, b) => (a.initialPrice ?? 1e12).compareTo(b.initialPrice ?? 1e12));
    return list;
  }

  Future<String> createJob({
    required String customerId,
    required String serviceId,
    required String serviceTitle,
    required GeoPoint exact,
  }) async {
    final id = _id('job');
    exactLocations[id] = exact;
    jobs[id] = Job(
      id: id,
      customerId: customerId,
      serviceId: serviceId,
      serviceTitle: serviceTitle,
      status: JobStatus.dispatching,
      matchingMode:
          isEmergencyService(serviceId) ? MatchingMode.emergency : MatchingMode.quotes,
      approxLocation: approximate(exact),
      createdAt: DateTime.now(),
    );
    notify();
    return id;
  }

  Future<void> dispatch(String jobId) async {
    final job = jobs[jobId];
    if (job == null || job.technicianId != null) return;
    if (job.status != JobStatus.dispatching && job.status != JobStatus.offerPending) {
      return;
    }
    final used = offers.values.where((o) => o.jobId == jobId).map((o) => o.technicianId).toSet();
    final ranked = users.values
        .where((u) => u.role == UserRole.technician)
        .where((u) => u.isOnline && u.verified && u.walletBalance >= AppConstants.minWalletBalance)
        .where((u) => u.serviceIds.contains(job.serviceId))
        .where((u) => !used.contains(u.id))
        .map((u) {
          final geo = u.geo ?? const GeoPoint(0, 0);
          final km = haversineKm(
            job.approxLocation.latitude,
            job.approxLocation.longitude,
            geo.latitude,
            geo.longitude,
          );
          return (user: u, km: km);
        })
        .where((t) => t.km <= AppConstants.maxMatchKm)
        .toList()
      ..sort((a, b) => a.km.compareTo(b.km));

    final take = job.isEmergency
        ? AppConstants.emergencyTechsPerRound
        : AppConstants.quoteTechsPerRound;
    final chosen = ranked.take(take).toList();
    if (chosen.isEmpty) {
      jobs[jobId] = _copyJob(job, status: JobStatus.noTechnician);
      notify();
      return;
    }
    final seconds = job.isEmergency
        ? AppConstants.emergencyOfferSeconds
        : AppConstants.quoteWindowSeconds;
    final expires = DateTime.now().add(Duration(seconds: seconds));
    for (final t in chosen) {
      final oid = _id('off');
      offers[oid] = JobOffer(
        id: oid,
        jobId: jobId,
        technicianId: t.user.id,
        status: OfferStatus.pending,
        expiresAt: expires,
        serviceTitle: job.serviceTitle,
        approxLocation: job.approxLocation,
        technicianName: t.user.name,
        ratingAvg: t.user.ratingAvg,
        distanceKm: t.km,
        verified: t.user.verified,
      );
    }
    jobs[jobId] = _copyJob(job, status: JobStatus.offerPending, expiresAt: expires);
    notify();
  }

  Job _copyJob(
    Job job, {
    JobStatus? status,
    String? technicianId,
    String? technicianName,
    double? initialPrice,
    double? finalPrice,
    double? receivedAmount,
    double? commissionAmount,
    GeoPoint? exactLocation,
    int? dispatchRound,
    DateTime? expiresAt,
    Warranty? warranty,
    JobRatings? ratings,
    bool clearTech = false,
  }) {
    return Job(
      id: job.id,
      customerId: job.customerId,
      serviceId: job.serviceId,
      serviceTitle: job.serviceTitle,
      status: status ?? job.status,
      matchingMode: job.matchingMode,
      approxLocation: job.approxLocation,
      createdAt: job.createdAt,
      technicianId: clearTech ? null : (technicianId ?? job.technicianId),
      technicianName: clearTech ? null : (technicianName ?? job.technicianName),
      exactLocation: exactLocation ?? job.exactLocation,
      initialPrice: initialPrice ?? job.initialPrice,
      finalPrice: finalPrice ?? job.finalPrice,
      receivedAmount: receivedAmount ?? job.receivedAmount,
      commissionAmount: commissionAmount ?? job.commissionAmount,
      warranty: warranty ?? job.warranty,
      ratings: ratings ?? job.ratings,
      dispatchRound: dispatchRound ?? job.dispatchRound,
      expiresAt: expiresAt ?? job.expiresAt,
    );
  }

  Future<bool> acceptOffer({
    required String offerId,
    required String technicianId,
    required String technicianName,
    required double initialPrice,
  }) async {
    final offer = offers[offerId];
    final job = offer == null ? null : jobs[offer.jobId];
    if (offer == null || job == null) return false;
    if (offer.technicianId != technicianId || offer.status != OfferStatus.pending) {
      return false;
    }
    if (DateTime.now().isAfter(offer.expiresAt)) {
      offers[offerId] = _copyOffer(offer, status: OfferStatus.expired);
      notify();
      return false;
    }
    if (job.isEmergency) {
      jobs[job.id] = _copyJob(
        job,
        technicianId: technicianId,
        technicianName: technicianName,
        initialPrice: initialPrice,
        status: JobStatus.quoted,
      );
      offers[offerId] = _copyOffer(offer, status: OfferStatus.accepted, price: initialPrice);
      _expirePending(job.id);
      notify();
      return true;
    }
    offers[offerId] = _copyOffer(
      offer,
      status: OfferStatus.submitted,
      price: initialPrice,
      name: technicianName,
    );
    notify();
    final submitted = quotesFor(job.id).where((o) => o.status == OfferStatus.submitted);
    if (submitted.length >= AppConstants.maxQuotes) {
      await closeQuoteWindow(job.id);
    }
    return true;
  }

  JobOffer _copyOffer(
    JobOffer o, {
    OfferStatus? status,
    double? price,
    String? name,
  }) {
    return JobOffer(
      id: o.id,
      jobId: o.jobId,
      technicianId: o.technicianId,
      status: status ?? o.status,
      expiresAt: o.expiresAt,
      serviceTitle: o.serviceTitle,
      approxLocation: o.approxLocation,
      initialPrice: price ?? o.initialPrice,
      technicianName: name ?? o.technicianName,
      ratingAvg: o.ratingAvg,
      distanceKm: o.distanceKm,
      verified: o.verified,
    );
  }

  void _expirePending(String jobId) {
    for (final e in offers.entries.toList()) {
      if (e.value.jobId == jobId && e.value.status == OfferStatus.pending) {
        offers[e.key] = _copyOffer(e.value, status: OfferStatus.expired);
      }
    }
  }

  Future<void> closeQuoteWindow(String jobId) async {
    final job = jobs[jobId];
    if (job == null || job.technicianId != null || job.status != JobStatus.offerPending) {
      return;
    }
    if (job.isEmergency) return;
    _expirePending(jobId);
    final submitted = quotesFor(jobId).where((o) => o.status == OfferStatus.submitted).toList();
    if (submitted.isEmpty) {
      await maybeRedispatch(jobId, expirePending: false);
      return;
    }
    if (submitted.length == 1) {
      await _assign(jobId, submitted.first);
      return;
    }
    jobs[jobId] = _copyJob(job, status: JobStatus.comparing);
    notify();
  }

  Future<void> _assign(String jobId, JobOffer offer) async {
    final job = jobs[jobId]!;
    jobs[jobId] = _copyJob(
      job,
      technicianId: offer.technicianId,
      technicianName: offer.technicianName ?? 'فني',
      initialPrice: offer.initialPrice,
      status: JobStatus.quoted,
    );
    offers[offer.id] = _copyOffer(offer, status: OfferStatus.accepted);
    for (final e in offers.entries.toList()) {
      if (e.value.jobId != jobId || e.key == offer.id) continue;
      if (e.value.status == OfferStatus.submitted || e.value.status == OfferStatus.pending) {
        offers[e.key] = _copyOffer(e.value, status: OfferStatus.expired);
      }
    }
    notify();
  }

  Future<bool> customerSelectOffer(String jobId, JobOffer offer) async {
    final job = jobs[jobId];
    if (job == null || job.technicianId != null) return false;
    if (job.status != JobStatus.comparing && job.status != JobStatus.offerPending) {
      return false;
    }
    if (offer.status != OfferStatus.submitted) return false;
    await _assign(jobId, offer);
    return true;
  }

  Future<void> rejectOffer(String offerId) async {
    final o = offers[offerId];
    if (o == null) return;
    offers[offerId] = _copyOffer(o, status: OfferStatus.rejected);
    notify();
  }

  Future<void> onWindowExpired(String jobId) async {
    final job = jobs[jobId];
    if (job == null || job.status != JobStatus.offerPending) return;
    if (job.isEmergency) {
      await maybeRedispatch(jobId);
      return;
    }
    await closeQuoteWindow(jobId);
  }

  Future<void> maybeRedispatch(String jobId, {bool expirePending = true}) async {
    final job = jobs[jobId];
    if (job == null || job.technicianId != null) return;
    if (job.status != JobStatus.offerPending &&
        job.status != JobStatus.dispatching &&
        job.status != JobStatus.noTechnician) {
      return;
    }
    if (expirePending) _expirePending(jobId);
    if (job.status == JobStatus.noTechnician) {
      jobs[jobId] = _copyJob(job, status: JobStatus.dispatching, dispatchRound: 1);
      await dispatch(jobId);
      return;
    }
    final next =
        job.status == JobStatus.dispatching ? job.dispatchRound : job.dispatchRound + 1;
    if (next > AppConstants.maxDispatchRounds) {
      jobs[jobId] = _copyJob(job, status: JobStatus.noTechnician);
      notify();
      return;
    }
    jobs[jobId] = _copyJob(job, status: JobStatus.dispatching, dispatchRound: next);
    await dispatch(jobId);
  }

  Future<void> customerAcceptQuote(String jobId) async {
    final job = jobs[jobId];
    if (job == null) return;
    jobs[jobId] = _copyJob(
      job,
      status: JobStatus.enRoute,
      exactLocation: exactLocations[jobId],
    );
    notify();
  }

  Future<void> customerRejectQuote(String jobId) async {
    final job = jobs[jobId];
    if (job == null) return;
    _expirePending(jobId);
    jobs[jobId] = _copyJob(job, status: JobStatus.cancelled, clearTech: true);
    notify();
  }

  Future<void> markArrived(String jobId) async {
    final job = jobs[jobId];
    if (job == null) return;
    jobs[jobId] = _copyJob(job, status: JobStatus.arrived);
    notify();
  }

  Future<void> submitFinalQuote({
    required String jobId,
    required double finalPrice,
    required Warranty warranty,
  }) async {
    final job = jobs[jobId];
    if (job == null) return;
    jobs[jobId] = _copyJob(
      job,
      finalPrice: finalPrice,
      warranty: warranty,
      status: JobStatus.finalQuote,
    );
    notify();
  }

  Future<void> customerAcceptFinal(String jobId) async {
    final job = jobs[jobId];
    if (job == null) return;
    jobs[jobId] = _copyJob(job, status: JobStatus.inProgress);
    notify();
  }

  Future<void> completeJob({
    required String jobId,
    required double receivedAmount,
    required bool warrantyEnabled,
  }) async {
    final job = jobs[jobId];
    if (job == null) return;
    final commission = (receivedAmount * AppConstants.commissionRate * 100).round() / 100;
    jobs[jobId] = _copyJob(
      job,
      receivedAmount: receivedAmount,
      commissionAmount: commission,
      status: JobStatus.completed,
      warranty: Warranty(
        enabled: job.warranty.enabled,
        type: job.warranty.type,
        days: job.warranty.days,
        note: job.warranty.note,
        startsAt: warrantyEnabled ? DateTime.now() : null,
      ),
    );
    final techId = job.technicianId;
    if (techId != null) {
      final tech = users[techId];
      if (tech != null) {
        final next = tech.walletBalance - commission;
        users[techId] = tech.copyWith(
          walletBalance: next,
          isOnline: next < AppConstants.minWalletBalance ? false : tech.isOnline,
        );
      }
    }
    notify();
  }

  Future<void> rateAsCustomer(String jobId, int stars) async {
    final job = jobs[jobId];
    if (job == null) return;
    jobs[jobId] = _copyJob(
      job,
      ratings: JobRatings(
        customerToTech: stars,
        techToCustomer: job.ratings.techToCustomer,
      ),
    );
    notify();
  }

  Future<void> rateAsTechnician(String jobId, int stars) async {
    final job = jobs[jobId];
    if (job == null) return;
    jobs[jobId] = _copyJob(
      job,
      ratings: JobRatings(
        customerToTech: job.ratings.customerToTech,
        techToCustomer: stars,
      ),
    );
    notify();
  }

  Future<void> markRatedIfDone(String jobId) async {
    final job = jobs[jobId];
    if (job == null) return;
    if (job.ratings.bothDone) {
      jobs[jobId] = _copyJob(job, status: JobStatus.rated);
      notify();
    }
  }
}
