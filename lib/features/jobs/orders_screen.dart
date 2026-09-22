import 'package:flutter/material.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/jobs/job_detail_screen.dart';
import 'package:barrr/features/jobs/job_present.dart';
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldTopBar(caption: 'الطلبات'),
        Expanded(
          child: StreamBuilder<List<Job>>(
            stream: widget.stream,
            builder: (context, snap) {
              final rows = snap.data ?? const <Job>[];
              if (snap.connectionState == ConnectionState.waiting &&
                  rows.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              final shown = rows.where((j) => _matches(_filter, j)).toList();
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _Filters(
                    filter: _filter,
                    counts: (
                      rows.length,
                      rows.where((j) => jobIsOpen(j)).length,
                      rows.where((j) => jobIsDone(j)).length,
                      rows.where((j) => jobIsClosed(j)).length,
                    ),
                    onChanged: (f) => setState(() => _filter = f),
                  ),
                  const SizedBox(height: 16),
                  if (rows.isEmpty)
                    const _Empty(text: 'لا توجد طلبات بعد. ابدأ من الرئيسية.')
                  else if (shown.isEmpty)
                    const _Empty(text: 'لا توجد طلبات في هذا التصنيف.')
                  else ...[
                    _FeaturedJob(
                      job: shown.first,
                      onOpen: () => openJobDetail(context, shown.first, widget.profile),
                    ),
                    if (shown.length > 1) ...[
                      const SizedBox(height: 18),
                      const SectionLabel('الطلبات السابقة'),
                      for (final job in shown.skip(1)) ...[
                        _OrderTile(
                          job: job,
                          onOpen: () => openJobDetail(context, job, widget.profile),
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
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final item = items[i];
          final on = filter == item.$1;
          return InkWell(
            onTap: () => onChanged(item.$1),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? AppColors.slate : AppColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: on ? AppColors.slate : AppColors.outline),
              ),
              child: Text(
                '${item.$2} ${item.$3}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: on ? Colors.white : AppColors.ink,
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
    final colors = jobStatusColors(job.status);
    final price = job.finalPrice ?? job.receivedAmount ?? job.initialPrice;
    return FieldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  jobCode(job),
                  style: const TextStyle(color: AppColors.inkSoft, fontSize: 12),
                ),
              ),
              StatusPill(
                label: jobStatusLabel(job.status),
                color: colors.$1,
                background: colors.$2,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            job.serviceTitle ?? 'طلب خدمة',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            formatWhen(job.createdAt),
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 12),
          ),
          if (job.technicianName != null && job.technicianName!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('الفني: ${job.technicianName}'),
          ],
          if (price != null) ...[
            const SizedBox(height: 10),
            Text(
              formatIqd(price),
              style: const TextStyle(
                color: AppColors.emeraldDeep,
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onOpen,
            child: const Text('عرض التفاصيل'),
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
    final colors = jobStatusColors(job.status);
    final price = job.finalPrice ?? job.receivedAmount ?? job.initialPrice;
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(16),
      child: FieldCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.serviceTitle ?? 'طلب خدمة',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${jobCode(job)} · ${formatWhen(job.createdAt)}',
                    style: const TextStyle(color: AppColors.inkSoft, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusPill(
                  label: jobStatusLabel(job.status),
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
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return FieldCard(
      child: Text(text, style: const TextStyle(color: AppColors.inkSoft)),
    );
  }
}
