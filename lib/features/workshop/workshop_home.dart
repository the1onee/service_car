import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/constants.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/auth/add_phone_screen.dart';
import 'package:barrr/features/jobs/orders_screen.dart';
import 'package:barrr/features/notifications/notifications_screen.dart';
import 'package:barrr/features/shared/address_map_picker.dart';
import 'package:barrr/features/shared/app_network_or_data_image.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/features/workshop/workshop_quote_sheet.dart';
import 'package:barrr/models/app_settings.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/job.dart';
import 'package:barrr/models/job_offer.dart';
import 'package:barrr/models/wallet_entry.dart';
import 'package:barrr/models/wallet_top_up.dart';
import 'package:barrr/services/fcm_service.dart';
import 'package:barrr/services/profile_photo_upload.dart';
import 'package:barrr/services/wallet_top_up_upload.dart';

part 'workshop_wallet.part.dart';
part 'workshop_account.part.dart';

/// لوحة الورشة: استقبال طلبات القطع وتقديم عروض الأسعار.
class WorkshopHome extends StatefulWidget {
  const WorkshopHome({super.key, required this.profile});

  final AppUser profile;

  @override
  State<WorkshopHome> createState() => _WorkshopHomeState();
}

enum _BoardFilter { incoming, waiting, accepted }

class _WorkshopHomeState extends State<WorkshopHome> {
  JobOffer? _quoting;
  var _booted = false;
  var _tab = 0;
  var _filter = _BoardFilter.incoming;
  VoidCallback? _fcmFocusListener;
  FcmService? _fcm;
  List<JobOffer> _pendingOffers = const [];
  List<JobOffer> _submittedOffers = const [];
  StreamSubscription? _offersSub;
  StreamSubscription? _submittedSub;
  Stream<AppUser?>? _userStream;
  Stream<List<Job>>? _recentJobsStream;
  Stream<AppSettings>? _settingsStream;

  static bool _withinOneDay(DateTime? at) {
    if (at == null) return true;
    return DateTime.now().difference(at) < const Duration(days: 1);
  }

  List<JobOffer> get _freshPending =>
      _pendingOffers.where((o) => _withinOneDay(o.createdAt)).toList();

  List<JobOffer> get _freshSubmitted =>
      _submittedOffers.where((o) => _withinOneDay(o.createdAt)).toList();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppScope.of(context);
    _userStream ??= scope.users.watch(widget.profile.id);
    _settingsStream ??= scope.settings.watchSettings();
    if (_booted) return;
    _booted = true;
    _fcm = scope.fcm;
    _fcmFocusListener = () {
      final id = scope.fcm.focusJobId.value;
      if (id == null || id.isEmpty || !mounted) return;
      setState(() {
        _tab = 0;
        _filter = _BoardFilter.incoming;
      });
      scope.fcm.focusJobId.value = null;
    };
    scope.fcm.focusJobId.addListener(_fcmFocusListener!);
    _offersSub = scope.jobs.watchPendingOffers(widget.profile.id).listen(
      (offers) {
        if (!mounted) return;
        setState(() => _pendingOffers = offers);
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _pendingOffers = const []);
      },
    );
    _submittedSub = scope.jobs.watchSubmittedOffers(widget.profile.id).listen(
      (offers) {
        if (!mounted) return;
        setState(() => _submittedOffers = offers);
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _submittedOffers = const []);
      },
    );
  }

  Stream<List<Job>> _ensureRecentJobs() {
    return _recentJobsStream ??=
        AppScope.of(context).jobs.watchRecentForTechnician(widget.profile.id);
  }

  void _onTab(int i) {
    if (i == _tab) return;
    setState(() {
      if (i != _tab) _recentJobsStream = null;
      _tab = i;
    });
  }

  @override
  void dispose() {
    _offersSub?.cancel();
    _submittedSub?.cancel();
    if (_fcmFocusListener != null) {
      _fcm?.focusJobId.removeListener(_fcmFocusListener!);
    }
    super.dispose();
  }

  Future<void> _markShipped(Job job) async {
    await AppScope.of(context).jobs.markPartsShipped(job.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تأكيد تجهيز/إرسال القطعة للعميل.')),
    );
  }

  Future<void> _cancelJob(Job job) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('إلغاء الطلب'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'سبب الإلغاء (اختياري)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('تراجع'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('تأكيد الإلغاء'),
            ),
          ],
        );
      },
    ).whenComplete(controller.dispose);
    if (reason == null || !mounted) return;
    try {
      await AppScope.of(context).jobs.workshopCancelJob(
            job.id,
            reason: reason,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إلغاء الطلب.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  void _openQuote(JobOffer offer, {required bool locked}) {
    if (locked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الحساب مقفل — اشحن الرصيد المطلوب أولاً.'),
        ),
      );
      _onTab(2);
      return;
    }
    setState(() => _quoting = offer);
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.profile;
    final userStream = _userStream;
    if (userStream == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: _tab == 0 && _quoting == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_quoting != null) {
          setState(() => _quoting = null);
          return;
        }
        if (_tab != 0) _onTab(0);
      },
      child: Stack(
        children: [
          FieldShell(
            tab: _tab,
            onTab: _onTab,
            items: const [
              FieldNavItem(icon: Icons.home_rounded, label: 'الرئيسية'),
              FieldNavItem(icon: Icons.receipt_long_outlined, label: 'الطلبات'),
              FieldNavItem(
                icon: Icons.account_balance_wallet_outlined,
                label: 'المحفظة',
              ),
              FieldNavItem(icon: Icons.person_outline_rounded, label: 'الملف'),
            ],
            body: switch (_tab) {
              1 => StreamBuilder<AppUser?>(
                  stream: userStream,
                  builder: (context, snap) {
                    return OrdersScreen(
                      stream: _ensureRecentJobs(),
                      profile: snap.data ?? me,
                    );
                  },
                ),
              2 => StreamBuilder<AppUser?>(
                  stream: userStream,
                  builder: (context, snap) {
                    return _WalletPage(
                      me: snap.data ?? me,
                      city: (snap.data ?? me).address.isEmpty ? 'البصرة' : null,
                      onAccount: () => _onTab(3),
                    );
                  },
                ),
              3 => StreamBuilder<AppUser?>(
                  stream: userStream,
                  builder: (context, snap) {
                    return _AccountPage(
                      me: snap.data ?? me,
                      jobs: _ensureRecentJobs(),
                      onOpenOrders: () => _onTab(1),
                      onOpenWallet: () => _onTab(2),
                    );
                  },
                ),
              _ => StreamBuilder<AppUser?>(
                  stream: userStream,
                  builder: (context, snap) {
                    final profile = snap.data ?? me;
                    return StreamBuilder<AppSettings>(
                      stream: _settingsStream,
                      builder: (context, settingsSnap) {
                        final min = settingsSnap.data?.minWalletBalance ??
                            AppConstants.minWalletBalance;
                        return _buildBoard(profile, min);
                      },
                    );
                  },
                ),
            },
          ),
          if (_quoting != null)
            WorkshopQuoteSheet(
              offer: _quoting!,
              workshopName: me.name,
              onDone: () => setState(() => _quoting = null),
            ),
        ],
      ),
    );
  }

  Widget _buildBoard(AppUser profile, double minBalance) {
    final locked = profile.isWalletLocked(minBalance);
    final required = profile.requiredTopUp(minBalance);
    final firstName = () {
      final parts = profile.name.trim().split(RegExp(r'\s+'));
      return parts.isEmpty || parts.first.isEmpty ? 'بك' : parts.first;
    }();
    final specialty = profile.specialtyAr.isEmpty
        ? 'ورشة قطع غيار'
        : profile.specialtyAr;
    final pending = _freshPending;
    final waiting = _freshSubmitted;

    return ColoredBox(
      color: AppColors.canvas,
      child: Column(
        children: [
          Material(
            color: AppColors.canvas.withValues(alpha: 0.92),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 64,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const FieldMark(size: 32),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ورشة قطع غيار',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              specialty,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF45464D),
                              ),
                            ),
                          ],
                        ),
                      ),
                      NotificationsBellButton(uid: profile.id),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => _onTab(3),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                    children: [
                      const TextSpan(text: 'أهلاً، '),
                      TextSpan(text: firstName),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'طلبات تخصصك خلال آخر 24 ساعة',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.inkSoft,
                  ),
                ),
                if (locked) ...[
                  const SizedBox(height: 12),
                  _LockBanner(
                    requiredAmount: required,
                    onPay: () => _onTab(2),
                  ),
                ],
                const SizedBox(height: 14),
                _SegmentBar(
                  filter: _filter,
                  incomingCount: pending.length,
                  waitingCount: waiting.length,
                  onChanged: (f) => setState(() => _filter = f),
                ),
                const SizedBox(height: 12),
                if (_filter == _BoardFilter.incoming) ...[
                  if (pending.isEmpty)
                    const _EmptyBox('لا توجد طلبات جديدة حالياً.')
                  else
                    for (final offer in pending)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _IncomingOfferCard(
                          offer: offer,
                          onOpen: () =>
                              _openQuote(offer, locked: locked),
                        ),
                      ),
                ] else if (_filter == _BoardFilter.waiting) ...[
                  if (waiting.isEmpty)
                    const _EmptyBox('لا توجد عروض بانتظار قبول العميل.')
                  else
                    for (final offer in waiting)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _WaitingOfferCard(offer: offer),
                      ),
                ] else
                  StreamBuilder<List<Job>>(
                    stream: _ensureRecentJobs(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting &&
                          !snap.hasData &&
                          !snap.hasError) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snap.hasError) {
                        return const _EmptyBox(
                          'تعذر تحميل الطلبات. تحقق من الاتصال وأعد المحاولة.',
                        );
                      }
                      final jobs = snap.data ?? const <Job>[];
                      final accepted = jobs
                          .where(
                            (j) =>
                                _withinOneDay(j.createdAt) &&
                                (j.status == JobStatus.quoted ||
                                    j.status == JobStatus.enRoute ||
                                    j.status == JobStatus.arrived ||
                                    j.status == JobStatus.inProgress ||
                                    j.status == JobStatus.finalQuote),
                          )
                          .toList();
                      // ترحيل طلبات quoted القديمة إلى enRoute دون انتظار فتح التفاصيل.
                      for (final j in accepted) {
                        if (j.status == JobStatus.quoted &&
                            j.technicianId != null) {
                          AppScope.of(context)
                              .jobs
                              .promotePartsQuotedToEnRoute(j.id);
                        }
                      }
                      if (accepted.isEmpty) {
                        return const _EmptyBox('لا توجد طلبات قيد التنفيذ.');
                      }
                      return Column(
                        children: [
                          for (final job in accepted)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _AcceptedJobCard(
                                job: job,
                                onShip: () => _markShipped(job),
                                onCancel: () => _cancelJob(job),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LockBanner extends StatelessWidget {
  const _LockBanner({
    required this.requiredAmount,
    required this.onPay,
  });

  final double requiredAmount;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'الحساب مقفل',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.danger,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            requiredAmount > 0
                ? 'اشحن ${formatIqd(requiredAmount)} لاستئناف استقبال الطلبات.'
                : 'اشحن رصيد المحفظة لاستئناف استقبال الطلبات.',
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF45464D)),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: FilledButton(
              onPressed: onPay,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.slate,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                requiredAmount > 0
                    ? 'الرصيد المطلوب · ${formatIqd(requiredAmount)}'
                    : 'شحن الرصيد',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentBar extends StatelessWidget {
  const _SegmentBar({
    required this.filter,
    required this.incomingCount,
    required this.waitingCount,
    required this.onChanged,
  });

  final _BoardFilter filter;
  final int incomingCount;
  final int waitingCount;
  final ValueChanged<_BoardFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(_BoardFilter f, String label, {int count = 0}) {
      final on = filter == f;
      return Expanded(
        child: InkWell(
          onTap: () => onChanged(f),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              color: on ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: on
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                      color: on ? AppColors.ink : AppColors.inkSoft,
                    ),
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: on ? AppColors.amberDeep : AppColors.inkSoft,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          chip(_BoardFilter.incoming, 'جديدة', count: incomingCount),
          chip(_BoardFilter.waiting, 'انتظار', count: waitingCount),
          chip(_BoardFilter.accepted, 'تنفيذ'),
        ],
      ),
    );
  }
}

class _IncomingOfferCard extends StatelessWidget {
  const _IncomingOfferCard({required this.offer, required this.onOpen});

  final JobOffer offer;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final title = offer.partName.isNotEmpty
        ? offer.partName
        : (offer.serviceTitle ?? 'طلب قطع غيار');
    final car = [
      if (offer.carMake.isNotEmpty) offer.carMake,
      if (offer.carModel.isNotEmpty) offer.carModel,
    ].join(' ');
    final meta = [
      if (car.isNotEmpty) car,
      if (offer.distanceKm != null)
        '${offer.distanceKm!.toStringAsFixed(1)} كم',
      if (offer.specialtyAr.isNotEmpty) offer.specialtyAr,
    ].join(' · ');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  meta,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  onPressed: onOpen,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.slate,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'تقديم عرض سعر',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaitingOfferCard extends StatelessWidget {
  const _WaitingOfferCard({required this.offer});

  final JobOffer offer;

  @override
  Widget build(BuildContext context) {
    final title = offer.partName.isNotEmpty
        ? offer.partName
        : (offer.serviceTitle ?? 'طلب قطع غيار');
    final car = [
      if (offer.carMake.isNotEmpty) offer.carMake,
      if (offer.carModel.isNotEmpty) offer.carModel,
    ].join(' ');
    final conditionLabel = switch (offer.partCondition) {
      'oem' => 'أصلي وكالة',
      'aftermarket' => 'تجاري',
      'used' => 'مستعمل مفحوص',
      _ => offer.partCondition,
    };
    final details = [
      if (car.isNotEmpty) car,
      if (conditionLabel.isNotEmpty) conditionLabel,
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              const Text(
                'بانتظار القبول',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.amberDeep,
                ),
              ),
            ],
          ),
          if (offer.initialPrice != null) ...[
            const SizedBox(height: 6),
            Text(
              formatIqd(offer.initialPrice!),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
          if (details.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              details,
              style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
            ),
          ],
        ],
      ),
    );
  }
}

class _AcceptedJobCard extends StatelessWidget {
  const _AcceptedJobCard({
    required this.job,
    required this.onShip,
    required this.onCancel,
  });

  final Job job;
  final VoidCallback onShip;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final title =
        job.partName.isEmpty ? (job.serviceTitle ?? 'قطع غيار') : job.partName;
    final car = [
      if (job.carMake.isNotEmpty) job.carMake,
      if (job.carModel.isNotEmpty) job.carModel,
      if (job.carYear.isNotEmpty) job.carYear,
    ].join(' ');
    final meta = [
      if (car.isNotEmpty) car,
      if (job.initialPrice != null) formatIqd(job.initialPrice!),
    ].join(' · ');

    final waitingReceive = job.status == JobStatus.inProgress ||
        job.status == JobStatus.finalQuote;
    final canShip = job.status == JobStatus.quoted ||
        job.status == JobStatus.enRoute ||
        job.status == JobStatus.arrived;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                _statusAr(job.status),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkSoft,
                ),
              ),
            ],
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              meta,
              style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
            ),
          ],
          if (job.locationRevealed) ...[
            const SizedBox(height: 10),
            CustomerContactBlock(job: job),
          ],
          const SizedBox(height: 8),
          DeliveryAddressBlock(job: job),
          if (job.partImageUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 120,
                width: double.infinity,
                child: AppNetworkOrDataImage(source: job.partImageUrl),
              ),
            ),
          ],
          if (canShip) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: onShip,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.slate,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('تأكيد تجهيز وإرسال القطعة'),
              ),
            ),
          ],
          if (waitingReceive) ...[
            const SizedBox(height: 12),
            Text(
              'بانتظار تأكيد استلام العميل',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.emeraldDeep,
              ),
            ),
          ],
          if (job.technicianCanWithdraw) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onCancel,
                child: const Text('إلغاء الطلب'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _statusAr(JobStatus s) => switch (s) {
        JobStatus.quoted => 'بانتظار التجهيز',
        JobStatus.enRoute => 'جاري التجهيز',
        JobStatus.arrived => 'جاهز للإرسال',
        JobStatus.inProgress => 'أُرسل — بانتظار استلام العميل',
        JobStatus.finalQuote => 'أُرسل — بانتظار الاستلام',
        JobStatus.completed => 'تم الاستلام',
        _ => s.name,
      };
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
      ),
    );
  }
}
