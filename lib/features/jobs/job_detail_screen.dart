import 'package:flutter/material.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/customer/parts_offers_section.dart';
import 'package:barrr/features/customer/quote_compare_list.dart';
import 'package:barrr/features/customer/wash_job_details.dart';
import 'package:barrr/features/jobs/job_present.dart';
import 'package:barrr/features/jobs/rating_sheet.dart';
import 'package:barrr/features/oil_workshop/oil_job_details.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/features/warranty/warranty_claim_screen.dart';
import 'package:barrr/features/warranty/warranty_form.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/job.dart';

void openJobDetail(BuildContext context, Job job, AppUser profile) {
  Navigator.of(context).push(
    softPageRoute<void>(
      builder: (_) => JobDetailScreen(job: job, profile: profile),
    ),
  );
}

class JobDetailScreen extends StatelessWidget {
  const JobDetailScreen({
    super.key,
    required this.job,
    required this.profile,
  });

  final Job job;
  final AppUser profile;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final provider = profile.isTechnician ||
        profile.isWorkshop ||
        profile.isOilWorkshop ||
        profile.isPaintShop;
    final stream = provider
        ? scope.jobs.watchRecentForTechnician(profile.id)
        : scope.jobs.watchRecentForCustomer(profile.id);
    return StreamBuilder<List<Job>>(
      stream: stream,
      builder: (context, snap) {
        final rows = snap.data ?? const <Job>[];
        Job live = job;
        for (final row in rows) {
          if (row.id == job.id) {
            live = row;
            break;
          }
        }
        return _Body(job: live, profile: profile);
      },
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.job, required this.profile});

  final Job job;
  final AppUser profile;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  var _promoted = false;

  Job get job => widget.job;
  AppUser get profile => widget.profile;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybePromoteQuoted();
  }

  @override
  void didUpdateWidget(covariant _Body oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.job.status != job.status ||
        oldWidget.job.id != job.id) {
      _promoted = false;
      _maybePromoteQuoted();
    }
  }

  void _maybePromoteQuoted() {
    if (_promoted) return;
    if (!profile.isWorkshop || !job.isPartsOrder) return;
    if (job.status != JobStatus.quoted || job.technicianId == null) return;
    _promoted = true;
    AppScope.of(context).jobs.promotePartsQuotedToEnRoute(job.id);
  }

  @override
  Widget build(BuildContext context) {
    final parts = job.isPartsOrder;
    final oil = job.isOilOrder;
    final wash = job.isWashOrder;
    final colors = jobStatusColors(job.status, isParts: parts);
    final price = job.receivedAmount ?? job.finalPrice ?? job.initialPrice;
    final customer = !profile.isTechnician &&
        !profile.isWorkshop &&
        !profile.isOilWorkshop &&
        !profile.isPaintShop;
    final workshopViewer = profile.isWorkshop && parts;
    final showWorkshopDetails = customer &&
        (job.technicianName ?? '').isNotEmpty &&
        parts;
    final canShip = workshopViewer &&
        (job.status == JobStatus.quoted ||
            job.status == JobStatus.enRoute ||
            job.status == JobStatus.arrived);
    final waitingReceive = workshopViewer &&
        (job.status == JobStatus.inProgress ||
            job.status == JobStatus.finalQuote);
    final canConfirmReceive = customer &&
        parts &&
        (job.status == JobStatus.inProgress ||
            job.status == JobStatus.finalQuote ||
            job.status == JobStatus.arrived);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: Text(jobCode(job))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          FieldCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        wash
                            ? job.washDisplayTitle
                            : oil
                                ? job.oilDisplayTitle
                                : (job.serviceTitle ?? 'طلب خدمة'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 18),
                      ),
                    ),
                    StatusPill(
                      label: jobStatusLabel(
                        job.status,
                        isParts: parts,
                        isWash: wash,
                      ),
                      color: colors.$1,
                      background: colors.$2,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  formatWhen(job.createdAt),
                  style: const TextStyle(color: AppColors.inkSoft, fontSize: 12),
                ),
                if (job.specialtyAr.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'الاختصاص: ${job.specialtyAr}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF45464D),
                    ),
                  ),
                ],
                if (jobIsOpen(job)) ...[
                  const SizedBox(height: 14),
                  _Progress(
                    status: job.status,
                    isParts: parts,
                    isWash: wash,
                  ),
                ],
              ],
            ),
          ),
          if (wash) ...[
            const SizedBox(height: 12),
            WashJobDetailsCard.fromJob(
              job,
              showPhone: customer && job.customerPhone.trim().isNotEmpty,
            ),
          ] else if (oil) ...[
            const SizedBox(height: 12),
            OilJobDetailsCard.fromJob(
              job,
              showPhone: customer && job.customerPhone.trim().isNotEmpty,
            ),
          ],
          if (!customer && job.locationRevealed) ...[
            const SizedBox(height: 12),
            CustomerContactBlock(job: job, framed: true),
          ],
          const SizedBox(height: 12),
          if (showWorkshopDetails)
            FieldCard(
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.recessed,
                    child: Text(_initial(job.technicianName)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.technicianName ?? 'ورشة',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          job.specialtyAr.isNotEmpty
                              ? job.specialtyAr
                              : 'ورشة معيّنة للطلب',
                          style: const TextStyle(
                            color: AppColors.inkSoft,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const StatusPill(
                    label: 'معتمد',
                    icon: Icons.verified_outlined,
                  ),
                ],
              ),
            )
          else if ((job.technicianName ?? '').isNotEmpty)
            FieldCard(
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.recessed,
                    child: Text(_initial(job.technicianName)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.technicianName ??
                              (parts
                                  ? 'ورشة'
                                  : oil
                                      ? 'ورشة زيوت'
                                      : wash
                                          ? 'مغسل'
                                          : 'فني'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          parts
                              ? 'الورشة المعيّنة'
                              : oil
                                  ? 'ورشة الزيوت المعيّنة'
                                  : wash
                                      ? 'المغسل المعيّن'
                                      : 'الفني المعيّن',
                          style: const TextStyle(
                              color: AppColors.inkSoft, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const StatusPill(
                    label: 'معتمد',
                    icon: Icons.verified_outlined,
                  ),
                ],
              ),
            ),
          if (workshopViewer && job.technicianId == profile.id) ...[
            const SizedBox(height: 12),
            DeliveryAddressBlock(job: job, framed: true),
          ],
          if (customer && parts && jobIsOpen(job)) ...[
            const SizedBox(height: 12),
            FieldCard(
              child: PartsOffersSection(
                job: job,
                selectable: job.status == JobStatus.offerPending ||
                    job.status == JobStatus.comparing,
              ),
            ),
          ],
          if (customer &&
              (oil || job.isTechnicianJob) &&
              (job.status == JobStatus.offerPending ||
                  job.status == JobStatus.comparing)) ...[
            const SizedBox(height: 12),
            FieldCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    oil
                        ? 'عروض ورش الزيوت'
                        : wash
                            ? 'عروض الغسيل'
                            : 'عروض الفنيين',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  QuoteCompareList(job: job, selectable: true),
                ],
              ),
            ),
          ],
          if (customer &&
              (oil || job.isTechnicianJob) &&
              job.status == JobStatus.quoted) ...[
            const SizedBox(height: 12),
            FieldCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'السعر: ${price == null ? '—' : formatIqd(price)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () =>
                        AppScope.of(context).jobs.customerAcceptQuote(job.id),
                    child: const Text('قبول الطلب وبدء التوجه'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          FieldCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'الحساب',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 10),
                if (parts) ...[
                  _MoneyRow(
                    label: 'سعر القطعة',
                    value: job.finalPrice ?? job.initialPrice,
                  ),
                  if (job.receivedAmount != null)
                    _MoneyRow(
                      label: 'المبلغ عند الاستلام',
                      value: job.receivedAmount,
                    ),
                ] else if (wash) ...[
                  _MoneyRow(
                    label: 'السعر المتفق',
                    value: job.finalPrice ?? job.initialPrice,
                  ),
                  _MoneyRow(
                    label: 'المبلغ المستلم نقداً',
                    value: job.receivedAmount,
                  ),
                ] else ...[
                  _MoneyRow(label: 'السعر المبدئي', value: job.initialPrice),
                  _MoneyRow(label: 'السعر النهائي', value: job.finalPrice),
                  _MoneyRow(
                      label: 'المبلغ المستلم نقداً',
                      value: job.receivedAmount),
                ],
                if (!customer && job.commissionAmount != null)
                  _MoneyRow(label: 'عمولة المنصة', value: job.commissionAmount),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        parts ? 'المبلغ المتفق' : 'المبلغ الظاهر',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      price == null ? '—' : formatIqd(price),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: AppColors.emeraldDeep,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  parts
                      ? 'الدفع كاش عند استلام القطعة على باب الزبون.'
                      : AppStrings.cashNote,
                  style: const TextStyle(
                      color: AppColors.inkSoft, fontSize: 12),
                ),
              ],
            ),
          ),
          if (canShip) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: () => _shipParts(context),
                child: const Text('تأكيد تجهيز وإرسال القطعة'),
              ),
            ),
          ],
          if (job.vendorNote.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            FieldCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'ملاحظات',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(job.vendorNote.trim()),
                ],
              ),
            ),
          ],
          if (waitingReceive) ...[
            const SizedBox(height: 16),
            FieldCard(
              child: Text(
                'بانتظار تأكيد استلام العميل',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.emeraldDeep,
                ),
              ),
            ),
          ],
          if (canConfirmReceive) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: () => _confirmPartsReceived(context),
                child: const Text('استلام الطلب'),
              ),
            ),
          ],
          if (job.warranty.enabled) ...[
            const SizedBox(height: 12),
            _WarrantyCard(job: job, customer: customer, profile: profile),
          ],
          if (customer && job.customerCanCancel) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => _confirmCancel(context),
              child: const Text(AppStrings.cancelJob),
            ),
          ],
          if (customer &&
              (job.status == JobStatus.completed ||
                  job.status == JobStatus.rated) &&
              job.ratings.customerToTech == null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _rate(context),
              child: Text(
                parts
                    ? 'تقييم الورشة'
                    : oil
                        ? 'تقييم ورشة الزيوت'
                        : wash
                            ? 'تقييم المغسل'
                            : 'تقييم الفني',
              ),
            ),
          ],
          if (job.ratings.customerToTech != null) ...[
            const SizedBox(height: 12),
            FieldCard(
              child: Text(
                parts
                    ? 'تقييمك للورشة: ${job.ratings.customerToTech} / 5'
                    : 'تقييمك للفني: ${job.ratings.customerToTech} / 5',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmPartsReceived(BuildContext context) async {
    try {
      await AppScope.of(context).jobs.customerConfirmPartsReceived(job.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تأكيد استلام الطلب.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر تأكيد الاستلام: $e')),
      );
    }
  }

  Future<void> _shipParts(BuildContext context) async {
    try {
      await AppScope.of(context).jobs.markPartsShipped(job.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تأكيد تجهيز/إرسال القطعة للعميل.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر تأكيد الإرسال: $e')),
      );
    }
  }

  Future<void> _confirmCancel(BuildContext context) async {
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
              child: const Text('تأكيد'),
            ),
          ],
        );
      },
    ).whenComplete(controller.dispose);
    if (reason == null || !context.mounted) return;
    try {
      await AppScope.of(context).jobs.customerCancelJob(job.id, reason: reason);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إلغاء الطلب.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _rate(BuildContext context) async {
    final jobs = AppScope.of(context).jobs;
    final users = AppScope.of(context).users;
    final stars = await showRatingSheet(
      context,
      title: job.isPartsOrder
          ? 'قيّم الورشة'
          : job.isOilOrder
              ? 'قيّم ورشة الزيوت'
              : job.isWashOrder
                  ? 'قيّم المغسل'
                  : 'قيّم الفني',
    );
    if (stars == null || !context.mounted) return;
    await jobs.rateAsCustomer(job.id, stars);
    if (job.technicianId != null) {
      await users.applyRating(job.technicianId!, stars);
    }
    await jobs.markRatedIfDone(job.id);
  }
}

class _WarrantyCard extends StatelessWidget {
  const _WarrantyCard({
    required this.job,
    required this.customer,
    required this.profile,
  });

  final Job job;
  final bool customer;
  final AppUser profile;

  @override
  Widget build(BuildContext context) {
    final active = warrantyIsActive(job.warranty);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.emeraldTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_outlined, color: AppColors.emeraldDeep),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'ضمان الإصلاح',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              StatusPill(
                label: active ? 'ساري' : warrantyRemainingLabel(job.warranty),
                color: active ? AppColors.emeraldDeep : AppColors.inkSoft,
                background: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(warrantyLabel(job.warranty)),
          const SizedBox(height: 4),
          Text(
            warrantyRemainingLabel(job.warranty),
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 12),
          ),
          if (customer && active) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        WarrantyClaimScreen(job: job, profile: profile),
                  ),
                );
              },
              child: const Text('رفع مطالبة بالضمان'),
            ),
          ],
        ],
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({required this.label, required this.value});

  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(color: AppColors.inkSoft, fontSize: 13)),
          ),
          Text(
            value == null ? '—' : formatIqd(value!),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

String _initial(String? name) {
  final trimmed = (name ?? '').trim();
  if (trimmed.isEmpty) return 'ف';
  return trimmed.substring(0, 1);
}

class _Progress extends StatelessWidget {
  const _Progress({
    required this.status,
    this.isParts = false,
    this.isWash = false,
  });

  final JobStatus status;
  final bool isParts;
  final bool isWash;

  @override
  Widget build(BuildContext context) {
    final labels = isParts
        ? const ['القبول', 'التجهيز', 'الإرسال', 'الاستلام']
        : isWash
            ? const ['القبول', 'الطريق', 'الغسيل']
            : const ['القبول', 'الطريق', 'الفحص', 'العمل'];
    final active = switch (status) {
      JobStatus.dispatching ||
      JobStatus.offerPending ||
      JobStatus.comparing =>
        0,
      JobStatus.quoted || JobStatus.enRoute => isParts ? 1 : (isWash ? 1 : 0),
      JobStatus.arrived => isWash ? 2 : 2,
      JobStatus.finalQuote => isWash ? 2 : 2,
      JobStatus.inProgress => isWash ? 2 : 3,
      _ => isWash ? 2 : 3,
    };
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 3,
                color: i <= active ? AppColors.amber : AppColors.outline,
              ),
            ),
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: i <= active ? AppColors.amber : AppColors.recessed,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  i < active ? Icons.check : Icons.circle,
                  size: i < active ? 14 : 8,
                  color: i <= active ? AppColors.ink : AppColors.inkSoft,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                labels[i],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: i == active ? AppColors.ink : AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
