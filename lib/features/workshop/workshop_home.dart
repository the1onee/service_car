import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/jobs/orders_screen.dart';
import 'package:barrr/features/notifications/notifications_screen.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/features/workshop/workshop_quote_sheet.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/job.dart';
import 'package:barrr/models/job_offer.dart';
import 'package:barrr/services/fcm_service.dart';
import 'package:barrr/services/user_repository.dart';

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
  var _dutyBusy = false;
  bool? _duty;
  String? _dutyHint;
  VoidCallback? _fcmFocusListener;
  FcmService? _fcm;
  List<JobOffer> _pendingOffers = const [];
  StreamSubscription? _offersSub;
  late final Stream<AppUser?> _userStream;
  late final Stream<List<Job>> _recentJobsStream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_booted) return;
    _booted = true;
    final scope = AppScope.of(context);
    _userStream = scope.users.watch(widget.profile.id);
    _recentJobsStream = scope.jobs.watchRecentForTechnician(widget.profile.id);
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
    _offersSub = scope.jobs.watchPendingOffers(widget.profile.id).listen((
      offers,
    ) {
      if (!mounted) return;
      setState(() => _pendingOffers = offers);
    });
  }

  @override
  void dispose() {
    _offersSub?.cancel();
    if (_fcmFocusListener != null) {
      _fcm?.focusJobId.removeListener(_fcmFocusListener!);
    }
    super.dispose();
  }

  Future<void> _toggleOnline(bool value) async {
    if (_dutyBusy) return;
    setState(() {
      _dutyBusy = true;
      _duty = value;
      _dutyHint = null;
    });
    final scope = AppScope.of(context);
    try {
      final result = await scope.users.setOnline(widget.profile.id, value);
      if (!mounted) return;
      if (!result.ok) {
        setState(() {
          _duty = widget.profile.isOnline;
          _dutyHint = result.block == OnlineBlock.rejected
              ? 'الحساب مرفوض من الإدارة.'
              : 'بانتظار موافقة الإدارة لتفعيل الورشة.';
        });
        return;
      }
      setState(() {
        _duty = value;
        _dutyHint = value ? 'متاح لاستقبال طلبات التسعير' : null;
      });
    } finally {
      if (mounted) setState(() => _dutyBusy = false);
    }
  }

  Future<void> _markShipped(Job job) async {
    await AppScope.of(context).jobs.markPartsShipped(job.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تأكيد تجهيز/إرسال القطعة للعميل.')),
    );
  }

  Future<void> _markDelivered(Job job) async {
    final amount = job.billAmount;
    await AppScope.of(context).jobs.completeJob(
      jobId: job.id,
      receivedAmount: amount > 0 ? amount : 0,
      warrantyEnabled: job.warranty.enabled,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إكمال الطلب وتسليمه للعميل.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final online = _duty ?? widget.profile.isOnline;
    final me = widget.profile;

    return Stack(
      children: [
        FieldShell(
          tab: _tab,
          onTab: (i) => setState(() => _tab = i),
          items: const [
            FieldNavItem(icon: Icons.storefront_outlined, label: 'الورشة'),
            FieldNavItem(icon: Icons.receipt_long_outlined, label: 'الطلبات'),
            FieldNavItem(icon: Icons.notifications_outlined, label: 'تنبيهات'),
          ],
          body: switch (_tab) {
            1 => OrdersScreen(
                stream: _recentJobsStream,
                profile: me,
              ),
            2 => const NotificationsScreen(),
            _ => StreamBuilder<AppUser?>(
                stream: _userStream,
                builder: (context, snap) {
                  final profile = snap.data ?? me;
                  return _buildBoard(profile, online);
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
    );
  }

  Widget _buildBoard(AppUser profile, bool online) {
    final scope = AppScope.of(context);
    return ColoredBox(
      color: AppColors.canvas,
      child: Column(
        children: [
          FieldTopBar(
            city: profile.address.isEmpty ? 'البصرة' : null,
            caption: 'ورشة قطع غيار',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                NotificationsBellButton(uid: profile.id),
                IconButton(
                  tooltip: AppStrings.logout,
                  onPressed: () => scope.auth.signOut(),
                  icon: const Icon(Icons.logout_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Container(
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
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: online ? AppColors.emerald : AppColors.inkSoft,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              online
                                  ? 'متاح لاستقبال طلبات التسعير'
                                  : 'غير متاح حالياً',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: online ? AppColors.emerald : AppColors.inkSoft,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded,
                                  size: 14, color: AppColors.amber),
                              const SizedBox(width: 2),
                              Text(
                                profile.ratingAvg.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.amberDeep,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                ' (${profile.ratingCount} تقييم)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF45464D),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF131B2E),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.car_repair,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        profile.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    if (profile.isApproved) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.verified,
                                          size: 18, color: AppColors.emerald),
                                    ],
                                  ],
                                ),
                                Text(
                                  [
                                    if (profile.specialtyAr.isNotEmpty)
                                      profile.specialtyAr,
                                    if (profile.address.isNotEmpty)
                                      profile.address,
                                  ].join(' • ').isEmpty
                                      ? 'ورشة قطع غيار'
                                      : [
                                          if (profile.specialtyAr.isNotEmpty)
                                            profile.specialtyAr,
                                          if (profile.address.isNotEmpty)
                                            profile.address,
                                        ].join(' • '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF45464D),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: online,
                            onChanged: _dutyBusy ? null : _toggleOnline,
                          ),
                        ],
                      ),
                      if (_dutyHint != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _dutyHint!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                StreamBuilder<List<Job>>(
                  stream: scope.jobs.watchRecentForTechnician(profile.id),
                  builder: (context, snap) {
                    final jobs = snap.data ?? const <Job>[];
                    final accepted = jobs
                        .where(
                          (j) =>
                              j.status == JobStatus.quoted ||
                              j.status == JobStatus.enRoute ||
                              j.status == JobStatus.arrived ||
                              j.status == JobStatus.inProgress ||
                              j.status == JobStatus.finalQuote,
                        )
                        .toList();
                    // عروض قيد الانتظار: نعرضها ضمن الفلتر عبر Stream منفصل إن لزم
                    return Column(
                      children: [
                        _SegmentBar(
                          filter: _filter,
                          incomingCount: _pendingOffers.length,
                          waitingCount: 0,
                          onChanged: (f) => setState(() => _filter = f),
                        ),
                        const SizedBox(height: 12),
                        if (_filter == _BoardFilter.incoming) ...[
                          if (_pendingOffers.isEmpty)
                            _EmptyBox(
                              online
                                  ? 'لا توجد طلبات واردة حالياً.'
                                  : 'فعّل التوفر لاستقبال طلبات التسعير.',
                            )
                          else
                            for (final offer in _pendingOffers)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _IncomingOfferCard(
                                  offer: offer,
                                  onOpen: () =>
                                      setState(() => _quoting = offer),
                                ),
                              ),
                        ] else if (_filter == _BoardFilter.waiting)
                          const _EmptyBox(
                            'عروضك المرسلة تظهر للعميل حتى يقبل أحدها.',
                          )
                        else if (accepted.isEmpty)
                          const _EmptyBox('لا توجد طلبات مقبولة للتجهيز.')
                        else
                          for (final job in accepted)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _AcceptedJobCard(
                                job: job,
                                onShip: () => _markShipped(job),
                                onDeliver: () => _markDelivered(job),
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
    Widget chip(_BoardFilter f, String label, {int? badge, String? soft}) {
      final on = filter == f;
      return Expanded(
        child: InkWell(
          onTap: () => onChanged(f),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              color: on ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: on
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
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
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                      color: on ? AppColors.ink : const Color(0xFF45464D),
                    ),
                  ),
                ),
                if (badge != null && badge > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.amber,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ] else if (soft != null) ...[
                  const SizedBox(width: 2),
                  Text(
                    soft,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF45464D),
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
        color: AppColors.petrolTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          chip(_BoardFilter.incoming, 'طلبات واردة', badge: incomingCount),
          chip(_BoardFilter.waiting, 'عروض قيد الانتظار',
              soft: waitingCount > 0 ? '($waitingCount)' : null),
          chip(_BoardFilter.accepted, 'مقبولة للتجهيز'),
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
    final left = offer.remainingSeconds();
    final m = left ~/ 60;
    final s = (left % 60).toString().padLeft(2, '0');
    final title = offer.partName.isNotEmpty
        ? offer.partName
        : (offer.serviceTitle ?? 'طلب قطع غيار');
    final car = [
      if (offer.carMake.isNotEmpty) offer.carMake,
      if (offer.carModel.isNotEmpty) offer.carModel,
    ].join(' ');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Container(
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
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: AppColors.azureTint,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.schedule, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'ينتهي بعد $m:$s',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                    Text(
                      '#${offer.jobId.length > 5 ? offer.jobId.substring(0, 5).toUpperCase() : offer.jobId}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF45464D),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'القطعة المطلوبة',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.amberDeep,
                      ),
                    ),
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    if (car.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        car,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF45464D),
                        ),
                      ),
                    ],
                    if (offer.distanceKm != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'المسافة التقريبية ${offer.distanceKm!.toStringAsFixed(1)} كم',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: FilledButton(
                        onPressed: onOpen,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'فتح وتقديم عرض السعر',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AcceptedJobCard extends StatelessWidget {
  const _AcceptedJobCard({
    required this.job,
    required this.onShip,
    required this.onDeliver,
  });

  final Job job;
  final VoidCallback onShip;
  final VoidCallback onDeliver;

  @override
  Widget build(BuildContext context) {
    final title =
        job.partName.isEmpty ? (job.serviceTitle ?? 'قطع غيار') : job.partName;
    final car = [
      if (job.carMake.isNotEmpty) job.carMake,
      if (job.carModel.isNotEmpty) job.carModel,
      if (job.carYear.isNotEmpty) job.carYear,
    ].join(' ');
    final warranty = job.warranty.enabled
        ? (job.warranty.note?.isNotEmpty == true
            ? job.warranty.note!
            : '${job.warranty.days} يوم')
        : null;

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
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          if (car.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(car, style: const TextStyle(color: Color(0xFF45464D))),
          ],
          if (job.customerPhone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('هاتف: ${job.customerPhone}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
          if (warranty != null) ...[
            const SizedBox(height: 4),
            Text('الضمان: $warranty',
                style: const TextStyle(fontSize: 12, color: Color(0xFF45464D))),
          ],
          if (job.partImageUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 100,
                width: double.infinity,
                child: _Thumb(dataUrl: job.partImageUrl),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'الحالة: ${_statusAr(job.status)}'
            '${job.initialPrice != null ? ' · ${formatIqd(job.initialPrice!)}' : ''}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          if (job.status == JobStatus.quoted ||
              job.status == JobStatus.enRoute ||
              job.status == JobStatus.arrived)
            FilledButton(
              onPressed: onShip,
              style: FilledButton.styleFrom(backgroundColor: Colors.black),
              child: const Text('تأكيد إرسال القطعة للعميل'),
            )
          else if (job.status == JobStatus.inProgress ||
              job.status == JobStatus.finalQuote)
            FilledButton(
              onPressed: onDeliver,
              style: FilledButton.styleFrom(backgroundColor: Colors.black),
              child: const Text('تم التسليم للعميل'),
            ),
        ],
      ),
    );
  }

  String _statusAr(JobStatus s) => switch (s) {
        JobStatus.quoted => 'بانتظار التنفيذ',
        JobStatus.enRoute => 'قيد التوصيل',
        JobStatus.inProgress => 'جاري الإرسال',
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFF45464D)),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.dataUrl});

  final String dataUrl;

  @override
  Widget build(BuildContext context) {
    try {
      final comma = dataUrl.indexOf(',');
      final b64 = comma >= 0 ? dataUrl.substring(comma + 1) : dataUrl;
      return Image.memory(base64Decode(b64), fit: BoxFit.cover);
    } catch (_) {
      return const ColoredBox(color: Color(0xFFEFF4FF));
    }
  }
}
