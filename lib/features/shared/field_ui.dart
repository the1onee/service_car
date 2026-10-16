import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:barrr/core/app_brand.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/app_snackbar.dart';
import 'package:barrr/core/phone.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/shared/app_network_or_data_image.dart';
import 'package:barrr/models/app_user.dart';
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: body,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF334155) : AppColors.outline,
            ),
          ),
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
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return Material(
      color: bg.withValues(alpha: 0.92),
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
                          Flexible(
                            child: Text(
                              caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16),
                            ),
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
    final radius = BorderRadius.circular(size * 0.28);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.slate,
        borderRadius: radius,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        AppBrand.logoAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(
          Icons.car_repair_rounded,
          color: AppColors.amber,
          size: size * 0.55,
        ),
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF1E293B) : AppColors.surface,
      elevation: 1,
      shadowColor: isDark ? Colors.black38 : AppColors.slate.withValues(alpha: 0.12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : AppColors.outline,
        ),
      ),
      child: Padding(
        padding: padding,
        child: child,
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

String groupThousandsDigits(String digits) {
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return buf.toString();
}

String latinMoneyDigits(String raw) {
  var s = raw;
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const latin = '0123456789';
  for (var i = 0; i < arabic.length; i++) {
    s = s.replaceAll(arabic[i], latin[i]);
  }
  return s.replaceAll(RegExp(r'[^0-9]'), '');
}

/// يدرج فاصلة كل ثلاثة أرقام أثناء الكتابة ويبقي المؤشر على الرقم نفسه.
class IqdThousandsFormatter extends TextInputFormatter {
  const IqdThousandsFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = latinMoneyDigits(newValue.text);
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final formatted = groupThousandsDigits(digits);
    final end = newValue.selection.end.clamp(0, newValue.text.length);
    final digitsBefore = latinMoneyDigits(newValue.text.substring(0, end)).length;
    var pos = 0;
    var seen = 0;
    while (pos < formatted.length && seen < digitsBefore) {
      if (formatted[pos] != ',') seen++;
      pos++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: pos),
    );
  }
}

String formatIqd(num value, {bool signed = false, bool withUnit = true}) {
  final rounded = value.round();
  final neg = rounded < 0;
  final digits = groupThousandsDigits(rounded.abs().toString());
  final sign =
      !signed ? (neg ? '-' : '') : (neg ? '-' : (rounded > 0 ? '+' : ''));
  return withUnit ? '$sign$digits د.ع' : '$sign$digits';
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

String jobStatusLabel(
  JobStatus status, {
  bool isParts = false,
  bool isWash = false,
}) {
  if (isParts) {
    switch (status) {
      case JobStatus.dispatching:
      case JobStatus.offerPending:
        return 'بانتظار العروض';
      case JobStatus.comparing:
        return 'مقارنة العروض';
      case JobStatus.quoted:
      case JobStatus.providerQueued:
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
        return AppStrings.waitingForProviderTitle;
      case JobStatus.cancelled:
        return 'ملغى';
    }
  }
  if (isWash) {
    switch (status) {
      case JobStatus.dispatching:
      case JobStatus.offerPending:
      case JobStatus.comparing:
        return 'بانتظار عروض الغسيل';
      case JobStatus.quoted:
        return 'بانتظار التوجه';
      case JobStatus.providerQueued:
        return 'بانتظار دور المغسل';
      case JobStatus.enRoute:
        return 'مغسل في الطريق';
      case JobStatus.arrived:
      case JobStatus.finalQuote:
      case JobStatus.inProgress:
        return 'جاري الغسيل';
      case JobStatus.completed:
        return 'تم الغسيل';
      case JobStatus.rated:
        return 'مقيَّم';
      case JobStatus.noTechnician:
        return AppStrings.waitingForProviderTitle;
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
    case JobStatus.providerQueued:
      return 'بانتظار دور المزوّد';
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
      return AppStrings.waitingForProviderTitle;
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
        return (AppColors.danger, AppColors.dangerTint);
      case JobStatus.noTechnician:
        return (const Color(0xFF92400E), AppColors.amberTint);
      case JobStatus.inProgress:
      case JobStatus.finalQuote:
        return (AppColors.emeraldDeep, AppColors.emeraldTint);
      case JobStatus.quoted:
      case JobStatus.providerQueued:
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
      return (AppColors.danger, AppColors.dangerTint);
    case JobStatus.noTechnician:
      return (const Color(0xFF92400E), AppColors.amberTint);
    case JobStatus.enRoute:
    case JobStatus.arrived:
    case JobStatus.finalQuote:
    case JobStatus.providerQueued:
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

Future<void> signOutFrom(BuildContext context) async {
  final scope = AppScope.of(context);
  final uid = scope.auth.currentUid;
  if (uid != null && uid.isNotEmpty) {
    try {
      await scope.users.clearPushSession(uid);
    } catch (_) {}
  }
  await scope.auth.signOut();
}

Future<void> openCustomerInMaps(double lat, double lng) async {
  final uri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
  );
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (opened) return;
  await launchUrl(uri, mode: LaunchMode.platformDefault);
}

String mapsPointLink(double lat, double lng) =>
    'https://www.google.com/maps?q=$lat,$lng';

Future<void> copyPhoneNumber(BuildContext context, String phone) async {
  final value = phone.trim();
  if (value.isEmpty) return;
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) return;
  AppSnackBar.showSuccess(context, 'تم نسخ رقم الهاتف');
}

/// يفتح واتساب على الرقم مع نص يتضمن رابط الموقع.
Future<void> openWhatsAppLocation({
  required String phone,
  required String text,
}) async {
  final normalized = normalizeIraqiPhone(phone);
  final digits = (looksLikeIraqiMobile(normalized) ? normalized : phone)
      .replaceAll(RegExp(r'[^\d]'), '');
  if (digits.isEmpty) return;
  final uri = Uri.parse(
    'https://wa.me/$digits?text=${Uri.encodeComponent(text)}',
  );
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (opened) return;
  await launchUrl(uri, mode: LaunchMode.platformDefault);
}

String jobLocationWhatsAppText(Job job) {
  final lines = <String>['موقع الطلب'];
  final point = job.displayLocation;
  if (job.isTowOrder) {
    final pickup = job.pickupLabel.trim();
    lines.add(
      pickup.isEmpty
          ? 'التحميل: ${mapsPointLink(point.latitude, point.longitude)}'
          : 'التحميل ($pickup): ${mapsPointLink(point.latitude, point.longitude)}',
    );
    final drop = job.dropoffLocation;
    if (drop != null) {
      final label = job.dropoffLabel.trim();
      lines.add(
        label.isEmpty
            ? 'التنزيل: ${mapsPointLink(drop.latitude, drop.longitude)}'
            : 'التنزيل ($label): ${mapsPointLink(drop.latitude, drop.longitude)}',
      );
    }
  } else {
    final label = job.landmark.trim().isNotEmpty
        ? job.landmark.trim()
        : job.deliveryAddress.trim();
    lines.add(
      label.isEmpty
          ? mapsPointLink(point.latitude, point.longitude)
          : '$label: ${mapsPointLink(point.latitude, point.longitude)}',
    );
  }
  return lines.join('\n');
}

class _PhoneActions extends StatelessWidget {
  const _PhoneActions({
    required this.phone,
    required this.whatsAppText,
    this.mapsLat,
    this.mapsLng,
    this.whatsAppLabel = 'واتساب الموقع',
  });

  final String phone;
  final String whatsAppText;
  final double? mapsLat;
  final double? mapsLng;
  final String whatsAppLabel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 0,
      children: [
        if (phone.isNotEmpty)
          TextButton.icon(
            onPressed: () => copyPhoneNumber(context, phone),
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('نسخ الهاتف'),
          ),
        if (mapsLat != null && mapsLng != null)
          TextButton.icon(
            onPressed: () => openCustomerInMaps(mapsLat!, mapsLng!),
            icon: const Icon(Icons.map_outlined, size: 18),
            label: const Text('الخريطة'),
          ),
        if (phone.isNotEmpty)
          TextButton.icon(
            onPressed: () => openWhatsAppLocation(
              phone: phone,
              text: whatsAppText,
            ),
            icon: const Icon(Icons.chat_outlined, size: 18),
            label: Text(whatsAppLabel),
          ),
      ],
    );
  }
}

/// صورة ورقم هاتف العميل للمزوّد بعد قبول الطلب (`locationRevealed`).
class CustomerContactBlock extends StatefulWidget {
  const CustomerContactBlock({
    super.key,
    required this.job,
    this.framed = false,
  });

  final Job job;
  final bool framed;

  @override
  State<CustomerContactBlock> createState() => _CustomerContactBlockState();
}

class _CustomerContactBlockState extends State<CustomerContactBlock> {
  String? _photoUrl;
  var _started = false;
  var _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    if (!widget.job.locationRevealed) return;
    _started = true;
    _loading = true;
    _load();
  }

  @override
  void didUpdateWidget(covariant CustomerContactBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.job.customerId != widget.job.customerId ||
        (!oldWidget.job.locationRevealed && widget.job.locationRevealed)) {
      _started = false;
      _photoUrl = null;
      if (widget.job.locationRevealed) {
        _started = true;
        _loading = true;
        _load();
      }
    }
  }

  Future<void> _load() async {
    try {
      final user = await AppScope.of(context).users.get(widget.job.customerId);
      if (!mounted) return;
      setState(() {
        _photoUrl = user?.photoUrl.trim();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    if (!job.locationRevealed) return const SizedBox.shrink();

    final phone = job.customerPhone.trim();
    final photo = (_photoUrl ?? '').trim();
    final point = job.displayLocation;
    final hasPoint = point.latitude != 0 || point.longitude != 0;
    if (phone.isEmpty && photo.isEmpty && !_loading && !hasPoint) {
      return const SizedBox.shrink();
    }

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ClipOval(
              child: SizedBox(
                width: 52,
                height: 52,
                child: photo.isNotEmpty
                    ? AppNetworkOrDataImage(
                        source: photo,
                        memCacheWidth: 160,
                        errorColor: AppColors.recessed,
                      )
                    : ColoredBox(
                        color: AppColors.recessed,
                        child: _loading
                            ? const Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : const Icon(
                                Icons.person_outline,
                                color: AppColors.inkSoft,
                              ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'هاتف العميل',
                    style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    phone.isEmpty ? '—' : phone,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.start,
                  ),
                ],
              ),
            ),
          ],
        ),
        _PhoneActions(
          phone: phone,
          whatsAppText: jobLocationWhatsAppText(job),
          mapsLat: hasPoint ? point.latitude : null,
          mapsLng: hasPoint ? point.longitude : null,
          whatsAppLabel: 'واتساب للعميل',
        ),
      ],
    );

    if (!widget.framed) return body;
    return FieldCard(child: body);
  }
}

/// هاتف المزوّد المعيّن، مع نسخ الرقم وإرسال موقع الطلب إليه على واتساب.
class ProviderContactBlock extends StatefulWidget {
  const ProviderContactBlock({
    super.key,
    required this.job,
    this.framed = false,
  });

  final Job job;
  final bool framed;

  @override
  State<ProviderContactBlock> createState() => _ProviderContactBlockState();
}

class _ProviderContactBlockState extends State<ProviderContactBlock> {
  String _phone = '';
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  @override
  void didUpdateWidget(covariant ProviderContactBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.job.technicianId != widget.job.technicianId) {
      _phone = '';
      _load();
    }
  }

  Future<void> _load() async {
    final id = (widget.job.technicianId ?? '').trim();
    if (id.isEmpty) return;
    try {
      final user = await AppScope.of(context).users.get(id);
      if (!mounted) return;
      setState(() => _phone = user?.phone.trim() ?? '');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final id = (job.technicianId ?? '').trim();
    if (id.isEmpty || job.isPartsOrder || !job.locationRevealed) {
      return const SizedBox.shrink();
    }
    final phone = _phone.trim();
    final point = job.displayLocation;
    final hasPoint = point.latitude != 0 || point.longitude != 0;
    final name = (job.technicianName ?? '').trim().isEmpty
        ? 'المزوّد'
        : job.technicianName!.trim();
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'هاتف $name',
          style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 2),
        Text(
          phone.isEmpty ? '—' : phone,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.start,
        ),
        _PhoneActions(
          phone: phone,
          whatsAppText: jobLocationWhatsAppText(job),
          mapsLat: hasPoint ? point.latitude : null,
          mapsLng: hasPoint ? point.longitude : null,
          whatsAppLabel: 'واتساب الموقع',
        ),
      ],
    );
    if (!widget.framed) return body;
    return FieldCard(child: body);
  }
}

/// عنوان التوصيل للورشة المعيّنة. الطلبات القديمة بلا عنوان منسوخ تُقرأ من ملف العميل.
class DeliveryAddressBlock extends StatefulWidget {
  const DeliveryAddressBlock({super.key, required this.job, this.framed = false});

  final Job job;
  final bool framed;

  @override
  State<DeliveryAddressBlock> createState() => _DeliveryAddressBlockState();
}

class _DeliveryAddressBlockState extends State<DeliveryAddressBlock> {
  AppUser? _customer;
  var _started = false;
  var _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    final job = widget.job;
    if (job.deliveryAddress.trim().isNotEmpty && job.exactLocation != null) {
      return;
    }
    _started = true;
    _loading = true;
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await AppScope.of(context).users.get(widget.job.customerId);
      if (!mounted) return;
      setState(() {
        _customer = user;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final saved = job.deliveryAddress.trim();
    final address = saved.isNotEmpty ? saved : (_customer?.address.trim() ?? '');
    final GeoPoint? geo = job.exactLocation ?? _customer?.geo;
    if (address.isEmpty && geo == null) {
      if (_loading) {
        return const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      }
      return const SizedBox.shrink();
    }
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'عنوان التوصيل',
          style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
        ),
        if (address.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, size: 18, color: AppColors.amberDeep),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  address,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
        if (geo != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => openCustomerInMaps(geo.latitude, geo.longitude),
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('فتح العنوان في الخريطة'),
            ),
          ),
      ],
    );
    if (!widget.framed) return body;
    return FieldCard(child: body);
  }
}
