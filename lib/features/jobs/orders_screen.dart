import 'package:flutter/material.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/jobs/job_detail_screen.dart';
import 'package:barrr/features/jobs/job_present.dart';
import 'package:barrr/features/notifications/notifications_screen.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/job.dart';

enum OrdersFilter { all, open, done, cancelled }

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({
    super.key,
    required this.stream,
    required this.profile,
  });

  final Stream<List<Job>> stream;
  final AppUser profile;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  var _filter = OrdersFilter.all;
  late final Stream<List<Job>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = widget.stream;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF8F9FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FieldTopBar(
            caption: 'الطلبات',
            trailing: NotificationsBellButton(uid: widget.profile.id),
          ),
          Expanded(
            child: StreamBuilder<List<Job>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: _Empty(
                        icon: Icons.error_outline,
                        title: 'تعذر تحميل الطلبات',
                        text: 'تحقق من الاتصال ثم أعد المحاولة.',
                      ),
                    ),
                  );
                }
                final rows = snap.data ?? const <Job>[];
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final open = rows.where(jobIsOpen).length;
                final done = rows.where(jobIsDone).length;
                final closed = rows.where(jobIsClosed).length;
                final shown = rows.where((j) => _matches(_filter, j)).toList();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: [
                    _OrdersHero(
                      total: rows.length,
                      open: open,
                      done: done,
                    ),
                    const SizedBox(height: 14),
                    _Filters(
                      filter: _filter,
                      counts: (rows.length, open, done, closed),
                      onChanged: (f) => setState(() => _filter = f),
                    ),
                    const SizedBox(height: 16),
                    if (rows.isEmpty)
                      const _Empty(
                        icon: Icons.assignment_outlined,
                        title: 'لا توجد طلبات',
                      )
                    else if (shown.isEmpty)
                      const _Empty(
                        icon: Icons.filter_alt_outlined,
                        title: 'لا نتائج',
                      )
                    else ...[
                      _FeaturedJob(
                        job: shown.first,
                        onOpen: () => openJobDetail(
                            context, shown.first, widget.profile),
                      ),
                      if (shown.length > 1) ...[
                        const SizedBox(height: 18),
                        const Text(
                          'الطلبات السابقة',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final job in shown.skip(1)) ...[
                          _OrderTile(
                            job: job,
                            onOpen: () =>
                                openJobDetail(context, job, widget.profile),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

bool _matches(OrdersFilter filter, Job job) {
  switch (filter) {
    case OrdersFilter.all:
      return true;
    case OrdersFilter.open:
      return jobIsOpen(job);
    case OrdersFilter.done:
      return jobIsDone(job);
    case OrdersFilter.cancelled:
      return jobIsClosed(job);
  }
}

IconData _serviceIcon(Job job) {
  final id = job.serviceId;
  return switch (id) {
    'towing' => Icons.local_shipping_outlined,
    'oil' => Icons.oil_barrel_outlined,
    'wash' => Icons.local_car_wash_outlined,
    'parts' => Icons.build_circle_outlined,
    'locks' => Icons.lock_outline,
    'fuel' => Icons.local_gas_station_outlined,
    _ => Icons.handyman_outlined,
  };
}

class _OrdersHero extends StatelessWidget {
  const _OrdersHero({
    required this.total,
    required this.open,
    required this.done,
  });

  final int total;
  final int open;
  final int done;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.slate,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow(opacity: 0.16),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -18,
            bottom: -28,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.assignment,
                        color: AppColors.amber),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'طلباتي',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'تابع حالة طلباتك وعروض الأسعار',
                          style: TextStyle(
                            color: Color(0xFFBEC6E0),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _HeroStat(label: 'الكل', value: '$total')),
                  const SizedBox(width: 8),
                  Expanded(child: _HeroStat(label: 'جارية', value: '$open')),
                  const SizedBox(width: 8),
                  Expanded(child: _HeroStat(label: 'مكتملة', value: '$done')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Color(0xFFBEC6E0), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.filter,
    required this.counts,
    required this.onChanged,
  });

  final OrdersFilter filter;
  final (int, int, int, int) counts;
  final ValueChanged<OrdersFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = [
      (OrdersFilter.all, 'الكل', counts.$1),
      (OrdersFilter.open, 'جارية', counts.$2),
      (OrdersFilter.done, 'مكتملة', counts.$3),
      (OrdersFilter.cancelled, 'ملغاة', counts.$4),
    ];
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final item = items[i];
          final on = filter == item.$1;
          return Material(
            color: on ? AppColors.slate : Colors.white,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: () => onChanged(item.$1),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: on ? AppColors.slate : const Color(0xFFC6C6CD),
                  ),
                ),
                child: Text(
                  '${item.$2} · ${item.$3}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: on ? Colors.white : AppColors.ink,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FeaturedJob extends StatelessWidget {
  const _FeaturedJob({required this.job, required this.onOpen});

  final Job job;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = jobStatusColors(job.status, isParts: job.isPartsOrder);
    final price = job.finalPrice ?? job.receivedAmount ?? job.initialPrice;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.recessed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_serviceIcon(job), color: AppColors.amberDeep),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.isWashOrder
                          ? job.washDisplayTitle
                          : job.isOilOrder
                              ? job.oilDisplayTitle
                              : (job.serviceTitle ?? 'طلب خدمة'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${jobCode(job)} · ${formatWhen(job.createdAt)}',
                      style: const TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: jobStatusLabel(job.status, isParts: job.isPartsOrder),
                color: colors.$1,
                background: colors.$2,
              ),
            ],
          ),
          if (job.vehicleTypeTitle != null &&
              job.vehicleTypeTitle!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF4FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions_car_outlined,
                      size: 16, color: AppColors.amberDeep),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      job.vehicleTypeTitle!,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (job.technicianName != null && job.technicianName!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              job.technicianName!,
              style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
            ),
          ],
          if (price != null) ...[
            const SizedBox(height: 10),
            Text(
              formatIqd(price),
              style: const TextStyle(
                color: AppColors.emeraldDeep,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 46,
            child: FilledButton(
              onPressed: onOpen,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.slate,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'عرض التفاصيل',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.job, required this.onOpen});

  final Job job;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = jobStatusColors(job.status, isParts: job.isPartsOrder);
    final price = job.finalPrice ?? job.receivedAmount ?? job.initialPrice;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: AppTheme.cardShadow(),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.recessed,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(_serviceIcon(job),
                    size: 22, color: AppColors.slate),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.isWashOrder
                          ? job.washDisplayTitle
                          : job.isOilOrder
                              ? job.oilDisplayTitle
                              : (job.serviceTitle ?? 'طلب خدمة'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${jobCode(job)} · ${formatWhen(job.createdAt)}',
                      style: const TextStyle(
                          color: AppColors.inkSoft, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusPill(
                    label: jobStatusLabel(job.status, isParts: job.isPartsOrder),
                    color: colors.$1,
                    background: colors.$2,
                  ),
                  if (price != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      formatIqd(price),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.emeraldDeep,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    this.text,
  });

  final IconData icon;
  final String title;
  final String? text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow(),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.recessed,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.amberDeep),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          if (text != null && text!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              text!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
