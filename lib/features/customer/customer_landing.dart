import 'package:flutter/material.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/data/service_catalog.dart';
import 'package:barrr/features/notifications/notifications_screen.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/features/warranty/warranty_form.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/job.dart';
import 'package:barrr/models/service_item.dart';

/// الصفحة الرئيسية للعميل — مطابقة لتصميم لوحة الخدمات.
class CustomerLanding extends StatefulWidget {
  const CustomerLanding({
    super.key,
    required this.profile,
    required this.city,
    required this.addressLabel,
    required this.services,
    required this.recentJobs,
    required this.onServiceTap,
    required this.onEmergencyTap,
    required this.onOpenWarranties,
    required this.onOpenAccount,
    required this.onRefresh,
  });

  final AppUser profile;
  final String? city;
  final String addressLabel;
  final Stream<List<ServiceItem>> services;
  final Stream<List<Job>> recentJobs;
  final ValueChanged<ServiceItem> onServiceTap;
  final VoidCallback onEmergencyTap;
  final VoidCallback onOpenWarranties;
  final VoidCallback onOpenAccount;
  final Future<void> Function() onRefresh;

  @override
  State<CustomerLanding> createState() => _CustomerLandingState();
}

class _CustomerLandingState extends State<CustomerLanding> {

  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get _firstName {
    final parts = widget.profile.name.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? 'بك' : parts.first;
  }

  String get _locationPill {
    if (widget.addressLabel.trim().isNotEmpty) {
      final short = widget.addressLabel.split(RegExp(r'[،,]')).take(2).join('، ');
      return short.length > 28 ? '${short.substring(0, 28)}…' : short;
    }
    return widget.city?.isNotEmpty == true ? widget.city! : 'البصرة';
  }

  /// ترتيب الخدمات الأساسية كما في التصميم.
  List<ServiceItem> _coreServices(List<ServiceItem> all) {
    const order = ['technician', 'parts', 'oil', 'towing', 'wash'];
    final byId = {for (final s in all) s.id: s};
    final out = <ServiceItem>[];
    for (final id in order) {
      final s = byId[id] ?? seedServices.cast<ServiceItem?>().firstWhere(
            (x) => x?.id == id,
            orElse: () => null,
          );
      if (s != null) out.add(s);
    }
    return out;
  }

  List<ServiceItem> _filtered(List<ServiceItem> core) {
    final q = _query.trim();
    if (q.isEmpty) return core;
    return core
        .where(
          (s) =>
              s.titleAr.contains(q) ||
              s.descriptionAr.contains(q) ||
              s.category.contains(q),
        )
        .toList();
  }

  IconData _iconFor(String id) => switch (id) {
        'technician' => Icons.build_outlined,
        'parts' => Icons.settings_outlined,
        'oil' => Icons.oil_barrel_outlined,
        'towing' => Icons.rv_hookup,
        'wash' => Icons.shower_outlined,
        'paint' => Icons.format_paint_outlined,
        _ => Icons.handyman_outlined,
      };

  @override
  Widget build(BuildContext context) {
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
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.profile.name.isEmpty
                                        ? 'حسابي'
                                        : widget.profile.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                if (widget.city != null &&
                                    widget.city!.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.azureTint,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      widget.city!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF45464D),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      NotificationsBellButton(uid: widget.profile.id),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: widget.onOpenAccount,
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
            child: StreamBuilder<List<ServiceItem>>(
              stream: widget.services,
              builder: (context, snap) {
                final loaded = snap.data;
                final all = (loaded == null || loaded.isEmpty)
                    ? seedServices
                    : loaded;
                final core = _filtered(_coreServices(all));

                return RefreshIndicator(
                  color: AppColors.amberDeep,
                  backgroundColor: Colors.white,
                  displacement: 36,
                  strokeWidth: 2.6,
                  onRefresh: widget.onRefresh,
                  child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                              children: [
                                TextSpan(text: 'أهلاً بك، $_firstName '),
                                const TextSpan(
                                  text: '👋',
                                  style: TextStyle(fontSize: 18),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.azureTint,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 16,
                                color: AppColors.amberDeep,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _locationPill,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF45464D),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
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
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: Color(0xFF76777D)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _search,
                              decoration: const InputDecoration(
                                hintText: 'ابحث عن خدمة أو قطعة غيار...',
                                hintStyle: TextStyle(
                                  color: Color(0xFF76777D),
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onChanged: (v) => setState(() => _query = v),
                            ),
                          ),
                          if (_query.isNotEmpty)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.close, size: 18),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Emergency hero
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.slate,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          Positioned(
                            top: -40,
                            left: -40,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.amber
                                    .withValues(alpha: 0.12),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'تحتاج قطعة غيار؟',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 17,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.settings_outlined,
                                        color: AppColors.amber,
                                        size: 26,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  height: 48,
                                  child: FilledButton(
                                    onPressed: widget.onEmergencyTap,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.amber,
                                      foregroundColor: AppColors.ink,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.settings_outlined, size: 20),
                                        SizedBox(width: 6),
                                        Text(
                                          'طلب قطع غيار',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'الخدمات',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (core.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'لا توجد خدمات مطابقة للبحث.',
                            style: TextStyle(color: Color(0xFF45464D)),
                          ),
                        ),
                      )
                    else
                      _ServicesGrid(
                        items: core,
                        iconFor: _iconFor,
                        onTap: widget.onServiceTap,
                      ),
                    const SizedBox(height: 16),
                    StreamBuilder<List<Job>>(
                      stream: widget.recentJobs,
                      builder: (context, jobSnap) {
                        final activeWarranty = (jobSnap.data ?? const <Job>[])
                            .where(
                              (j) =>
                                  j.warranty.enabled &&
                                  warrantyIsActive(j.warranty),
                            )
                            .toList();
                        if (activeWarranty.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        final job = activeWarranty.first;
                        final hoursLeft = () {
                          final start = job.warranty.startsAt ?? job.createdAt;
                          final end =
                              start.add(Duration(days: job.warranty.days));
                          final h = end.difference(DateTime.now()).inHours;
                          return h < 0 ? 0 : h;
                        }();
                        return Material(
                          color: AppColors.petrolTint,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            onTap: widget.onOpenWarranties,
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFD3E4FE),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.verified_user,
                                      size: 18,
                                      color: AppColors.emerald,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                'ضمان سارٍ: ${job.serviceTitle ?? 'خدمة'}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: const BoxDecoration(
                                                color: AppColors.emerald,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          '${job.technicianName ?? 'مزوّد معتمد'} • ينتهي خلال $hoursLeft ساعة',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF45464D),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_back_ios_new,
                                    size: 16,
                                    color: Color(0xFF45464D),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ServicesGrid extends StatelessWidget {
  const _ServicesGrid({
    required this.items,
    required this.iconFor,
    required this.onTap,
  });

  final List<ServiceItem> items;
  final IconData Function(String id) iconFor;
  final ValueChanged<ServiceItem> onTap;

  @override
  Widget build(BuildContext context) {
    final wash = items.where((s) => s.id == 'wash').toList();
    final grid = items.where((s) => s.id != 'wash').toList();

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: grid.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 108,
            crossAxisSpacing: 12,
            mainAxisSpacing: 16,
          ),
          itemBuilder: (context, i) {
            final s = grid[i];
            return _ServiceTile(
              title: s.titleAr,
              icon: iconFor(s.id),
              onTap: () => onTap(s),
            );
          },
        ),
        if (wash.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final s in wash)
            _WashWideTile(
              title: s.titleAr,
              icon: iconFor(s.id),
              onTap: () => onTap(s),
            ),
        ],
      ],
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
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
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5EEFF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 22, color: AppColors.ink),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WashWideTile extends StatelessWidget {
  const _WashWideTile({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
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
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5EEFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 22, color: AppColors.ink),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const Icon(Icons.chevron_left, color: AppColors.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}
