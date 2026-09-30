import 'package:flutter/material.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/models/job.dart';

class FieldNavItem {
  const FieldNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// انتقال خفيف (fade + slide) لشاشات العميل.
Route<T> softPageRoute<T extends Object?>({required WidgetBuilder builder}) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.05, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
  );
}

class FieldShell extends StatelessWidget {
  const FieldShell({
    super.key,
    required this.tab,
    required this.onTab,
    required this.items,
    required this.body,
  });

  final int tab;
  final ValueChanged<int> onTab;
  final List<FieldNavItem> items;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: body,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.outline)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: InkWell(
                      onTap: () => onTab(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            items[i].icon,
                            size: 22,
                            color: tab == i
                                ? AppColors.amberDeep
                                : AppColors.inkSoft,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            items[i].label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  tab == i ? FontWeight.w700 : FontWeight.w500,
                              color: tab == i
                                  ? AppColors.amberDeep
                                  : AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FieldTopBar extends StatelessWidget {
  const FieldTopBar(
      {super.key, this.city, this.caption = 'خدمة ميدانية', this.trailing});

  final String? city;
  final String caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.canvas.withValues(alpha: 0.92),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const FieldMark(size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'طلب الفني',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          if (city != null && city!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.recessed,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                city!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        caption,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FieldMark extends StatelessWidget {
  const FieldMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.slate,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(Icons.car_repair_rounded,
          color: AppColors.amber, size: size * 0.55),
    );
  }
}

class FieldCard extends StatelessWidget {
  const FieldCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow(),
      ),
      child: Material(
        color: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.outline),
        ),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.color = AppColors.emerald,
    this.background = AppColors.emeraldTint,
    this.icon,
  });

  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    );
  }
}

String formatIqd(num value, {bool signed = false, bool withUnit = true}) {
  final rounded = value.round();
  final neg = rounded < 0;
  final digits = rounded.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  final sign =
      !signed ? (neg ? '-' : '') : (neg ? '-' : (rounded > 0 ? '+' : ''));
  return withUnit ? '$sign$buf د.ع' : '$sign$buf';
}

String formatWhen(DateTime? date) {
  if (date == null) return '';
  const months = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];
  final h = date.hour.toString().padLeft(2, '0');
  final m = date.minute.toString().padLeft(2, '0');
  return '${date.day} ${months[date.month - 1]} · $h:$m';
}

String jobStatusLabel(JobStatus status, {bool isParts = false}) {
  if (isParts) {
    switch (status) {
      case JobStatus.dispatching:
      case JobStatus.offerPending:
        return 'بانتظار العروض';
      case JobStatus.comparing:
        return 'مقارنة العروض';
      case JobStatus.quoted:
      case JobStatus.enRoute:
      case JobStatus.arrived:
        return 'جاري التجهيز';
      case JobStatus.finalQuote:
      case JobStatus.inProgress:
        return 'أُرسل — بانتظار الاستلام';
      case JobStatus.completed:
        return 'تم الاستلام';
      case JobStatus.rated:
        return 'مقيَّم';
      case JobStatus.noTechnician:
        return 'لا توجد ورشة';
      case JobStatus.cancelled:
        return 'ملغى';
    }
  }
  switch (status) {
    case JobStatus.dispatching:
    case JobStatus.offerPending:
      return 'جارٍ البحث';
    case JobStatus.comparing:
      return 'مقارنة العروض';
    case JobStatus.quoted:
      return 'بانتظار الموافقة';
    case JobStatus.enRoute:
      return 'في الطريق';
    case JobStatus.arrived:
      return 'وصل الفني';
    case JobStatus.finalQuote:
      return 'سعر نهائي';
    case JobStatus.inProgress:
      return 'قيد العمل';
    case JobStatus.completed:
      return 'مكتمل';
    case JobStatus.rated:
      return 'مقيَّم';
    case JobStatus.noTechnician:
      return 'لا يوجد فني';
    case JobStatus.cancelled:
      return 'ملغى';
  }
}

(Color, Color) jobStatusColors(JobStatus status, {bool isParts = false}) {
  if (isParts) {
    switch (status) {
      case JobStatus.completed:
      case JobStatus.rated:
        return (AppColors.emeraldDeep, AppColors.emeraldTint);
      case JobStatus.cancelled:
      case JobStatus.noTechnician:
        return (AppColors.danger, AppColors.dangerTint);
      case JobStatus.inProgress:
      case JobStatus.finalQuote:
        return (AppColors.emeraldDeep, AppColors.emeraldTint);
      case JobStatus.quoted:
      case JobStatus.enRoute:
      case JobStatus.arrived:
        return (const Color(0xFF92400E), AppColors.amberTint);
      default:
        return (AppColors.inkSoft, AppColors.recessed);
    }
  }
  switch (status) {
    case JobStatus.completed:
    case JobStatus.rated:
    case JobStatus.inProgress:
      return (AppColors.emeraldDeep, AppColors.emeraldTint);
    case JobStatus.cancelled:
    case JobStatus.noTechnician:
      return (AppColors.danger, AppColors.dangerTint);
    case JobStatus.enRoute:
    case JobStatus.arrived:
    case JobStatus.finalQuote:
    case JobStatus.quoted:
      return (const Color(0xFF92400E), AppColors.amberTint);
    default:
      return (AppColors.inkSoft, AppColors.recessed);
  }
}

class AccountHeader extends StatelessWidget {
  const AccountHeader(
      {super.key, required this.name, required this.subtitle, this.trailing});

  final String name;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return FieldCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.recessed,
            child: Text(
              name.isEmpty ? '؟' : name.substring(0, 1),
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.ink),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? 'بدون اسم' : name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.inkSoft, fontSize: 13)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

Future<void> signOutFrom(BuildContext context) {
  return AppScope.of(context).auth.signOut();
}
