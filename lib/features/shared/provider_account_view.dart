import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/app_snackbar.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/data/service_catalog.dart';
import 'package:barrr/features/auth/add_phone_screen.dart';
import 'package:barrr/features/legal/privacy_view_screen.dart';
import 'package:barrr/features/legal/terms_view_screen.dart';
import 'package:barrr/features/notifications/notifications_screen.dart';
import 'package:barrr/features/shared/account_shared.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/features/support/support_screen.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/service_item.dart';
import 'package:barrr/models/vehicle_type.dart';

/// صفحة حساب موحّدة لمزوّدي الخدمة (فني / ورشة زيوت / ورشة قطع).
class ProviderAccountView extends StatefulWidget {
  const ProviderAccountView({
    super.key,
    required this.me,
    required this.onOpenOrders,
    required this.onOpenWallet,
    required this.roleBadge,
    this.city,
    this.isActive = true,
    this.caption = 'حسابي',
    this.addressPickerTitle = 'تحديد عنوانك',
    this.midMenuTiles = const [],
  });

  final AppUser me;
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenWallet;
  final String roleBadge;
  final String? city;
  final bool isActive;
  final String caption;
  final String addressPickerTitle;

  /// عناصر قائمة إضافية بين المحفظة والهاتف (مع فواصل Divider بينها إن لزم).
  final List<Widget> midMenuTiles;

  @override
  State<ProviderAccountView> createState() => _ProviderAccountViewState();
}

class _ProviderAccountViewState extends State<ProviderAccountView> {
  var _uploadingPhoto = false;
  var _photoSaved = false;
  var _savingName = false;
  var _savingAddress = false;
  var _locationPrompted = false;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _maybePromptLocation());
    }
  }

  @override
  void didUpdateWidget(covariant ProviderAccountView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.me.geo == null && widget.me.geo != null) {
      _locationPrompted = true;
    }
    final becameActive = widget.isActive && !oldWidget.isActive;
    if (becameActive ||
        (!_locationPrompted && widget.isActive && widget.me.geo == null)) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _maybePromptLocation());
    }
  }

  void _maybePromptLocation() {
    if (!mounted || !widget.isActive || _locationPrompted || _savingAddress) {
      return;
    }
    if (widget.me.geo != null) {
      _locationPrompted = true;
      return;
    }
    _locationPrompted = true;
    _editAddress();
  }

  Future<void> _changePhoto() async {
    if (_uploadingPhoto) return;
    setState(() => _uploadingPhoto = true);
    final url = await AccountActions.changePhoto(context, uid: widget.me.id);
    if (!mounted) return;
    setState(() {
      _uploadingPhoto = false;
      if (url != null) _photoSaved = true;
    });
    if (url != null) {
      Future<void>.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) setState(() => _photoSaved = false);
      });
    }
  }

  Future<void> _editName() async {
    if (_savingName) return;
    setState(() => _savingName = true);
    await AccountActions.editName(
      context,
      uid: widget.me.id,
      currentName: widget.me.name,
    );
    if (mounted) setState(() => _savingName = false);
  }

  Future<void> _editAddress() async {
    if (_savingAddress) return;
    final me = widget.me;
    final LatLng? initial = me.geo != null
        ? LatLng(me.geo!.latitude, me.geo!.longitude)
        : null;
    setState(() => _savingAddress = true);
    await AccountActions.editAddress(
      context,
      uid: me.id,
      currentGeo: initial,
      currentAddress: me.address,
      title: widget.addressPickerTitle,
    );
    if (mounted) setState(() => _savingAddress = false);
  }

  Future<void> _editPhone() async {
    await AccountActions.editPhone(
      context,
      uid: widget.me.id,
      currentPhone: widget.me.phone,
    );
  }

  String _statusLabel(AppUser me) {
    return switch (me.verificationStatus) {
      VerificationStatus.approved => 'معتمد',
      VerificationStatus.rejected => 'مرفوض',
      VerificationStatus.pending => 'قيد التدقيق',
    };
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    final city = widget.city ?? me.cityNameAr;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          FieldTopBar(
            city: city.isEmpty ? null : city,
            caption: widget.caption,
            trailing: NotificationsBellButton(uid: me.id),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _ProviderProfileHero(
                  profile: me,
                  roleBadge: widget.roleBadge,
                  statusLabel: _statusLabel(me),
                  uploadingPhoto: _uploadingPhoto,
                  photoSaved: _photoSaved,
                  savingName: _savingName,
                  onChangePhoto: _changePhoto,
                  onEditName: _editName,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AccountStatCard(
                        icon: Icons.star_outline_rounded,
                        title: 'التقييم',
                        value: me.ratingAvg.toStringAsFixed(1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AccountStatCard(
                        icon: Icons.reviews_outlined,
                        title: 'عدد التقييمات',
                        value: '${me.ratingCount}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                AccountMenuCard(
                  children: [
                    AccountTile(
                      icon: Icons.assignment_outlined,
                      title: 'الطلبات',
                      onTap: widget.onOpenOrders,
                    ),
                    const Divider(height: 1),
                    AccountTile(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'المحفظة',
                      onTap: widget.onOpenWallet,
                    ),
                    if (widget.midMenuTiles.isNotEmpty) ...[
                      const Divider(height: 1),
                      ...widget.midMenuTiles,
                    ],
                    const Divider(height: 1),
                    AccountTile(
                      icon: Icons.phone_outlined,
                      title: AppStrings.phone,
                      subtitle: profilePhoneLabel(me.phone),
                      onTap: _editPhone,
                    ),
                    const Divider(height: 1),
                    AccountTile(
                      icon: Icons.location_on_outlined,
                      title: 'العنوان',
                      subtitle: _savingAddress
                          ? 'جاري الحفظ…'
                          : (me.address.trim().isEmpty
                              ? 'لا يوجد عنوان'
                              : me.address),
                      onTap: _savingAddress ? () {} : _editAddress,
                    ),
                    const Divider(height: 1),
                    const AccountThemeTile(),
                    const Divider(height: 1),
                    const AccountSoundTile(),
                    const Divider(height: 1),
                    AccountTile(
                      icon: Icons.description_outlined,
                      title: 'شروط الاستخدام',
                      onTap: () => TermsViewScreen.open(
                        context,
                        role: me.role,
                      ),
                    ),
                    const Divider(height: 1),
                    AccountTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'سياسة الخصوصية',
                      onTap: () => PrivacyViewScreen.open(context),
                    ),
                    const Divider(height: 1),
                    AccountTile(
                      icon: Icons.support_agent_outlined,
                      title: 'الدعم',
                      subtitle: 'اتصال أو إرسال تعليق',
                      onTap: () => SupportScreen.open(context, me),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => signOutFrom(context),
                    icon: const Icon(Icons.logout, color: AppColors.danger),
                    label: const Text(
                      'تسجيل الخروج',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.danger),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderProfileHero extends StatelessWidget {
  const _ProviderProfileHero({
    required this.profile,
    required this.roleBadge,
    required this.statusLabel,
    required this.uploadingPhoto,
    required this.photoSaved,
    required this.savingName,
    required this.onChangePhoto,
    required this.onEditName,
  });

  final AppUser profile;
  final String roleBadge;
  final String statusLabel;
  final bool uploadingPhoto;
  final bool photoSaved;
  final bool savingName;
  final VoidCallback onChangePhoto;
  final VoidCallback onEditName;

  @override
  Widget build(BuildContext context) {
    final photo = profile.photoUrl.trim();
    final initial =
        profile.name.trim().isEmpty ? '؟' : profile.name.trim().substring(0, 1);
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
            left: -20,
            bottom: -30,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            children: [
              GestureDetector(
                onTap: uploadingPhoto ? null : onChangePhoto,
                child: Stack(
                  alignment: Alignment.bottomLeft,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.amber, width: 2.5),
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: uploadingPhoto
                          ? const Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: AppColors.amber,
                                ),
                              ),
                            )
                          : photo.isEmpty
                              ? Center(
                                  child: Text(
                                    initial,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                )
                              : CachedNetworkImage(
                                  imageUrl: photo,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  errorWidget: (context, url, error) => Center(
                                    child: Text(
                                      initial,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                    ),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: photoSaved ? AppColors.emerald : AppColors.amber,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.slate, width: 2),
                      ),
                      child: Icon(
                        photoSaved ? Icons.check_rounded : Icons.camera_alt,
                        size: photoSaved ? 18 : 15,
                        color: photoSaved ? Colors.white : AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      profile.name.trim().isEmpty ? 'بدون اسم' : profile.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: savingName ? null : onEditName,
                    visualDensity: VisualDensity.compact,
                    icon: savingName
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.amber,
                            ),
                          )
                        : const Icon(Icons.edit_outlined, size: 18),
                    color: AppColors.amber,
                  ),
                ],
              ),
              Text(
                profilePhoneLabel(profile.phone),
                textDirection: profile.phone.trim().isEmpty
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                style: const TextStyle(
                  color: Color(0xFFBEC6E0),
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      roleBadge,
                      style: const TextStyle(
                        color: Color(0xFFFFDDB8),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel,
                      style: const TextStyle(
                        color: Color(0xFFBEC6E0),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// خدمات الفني (عرض فقط — تُدار من الإدارة).
class ProviderServicesTile extends StatelessWidget {
  const ProviderServicesTile({super.key, required this.me});

  final AppUser me;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ServiceItem>>(
      stream: AppScope.of(context).users.watchServices(),
      builder: (context, snap) {
        final catalog = (snap.data == null || snap.data!.isEmpty)
            ? seedServices
            : snap.data!;
        final names = catalog
            .where((s) => me.serviceIds.contains(s.id))
            .map((s) => s.titleAr)
            .toList();
        return AccountTile(
          icon: Icons.handyman_outlined,
          title: 'الخدمات',
          subtitle: names.isEmpty ? 'تُحدَّد من الإدارة' : names.join(' · '),
          onTap: () {
            AppSnackBar.showInfo(
              context,
              'الخدمات تُدار من الإدارة ولا يمكن تعديلها هنا',
            );
          },
        );
      },
    );
  }
}

/// أنواع سيارات الفني (عرض فقط).
class ProviderVehiclesTile extends StatelessWidget {
  const ProviderVehiclesTile({super.key, required this.me});

  final AppUser me;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<VehicleType>>(
      stream: AppScope.of(context).users.watchVehicleTypes(),
      builder: (context, snap) {
        final catalog = (snap.data == null || snap.data!.isEmpty)
            ? seedVehicleTypes
            : snap.data!;
        final names = catalog
            .where((t) => me.vehicleTypeIds.contains(t.id))
            .map((t) => t.nameAr)
            .toList();
        return AccountTile(
          icon: Icons.directions_car_outlined,
          title: 'أنواع السيارات',
          subtitle: names.isEmpty ? 'تُحدَّد من الإدارة' : names.join(' · '),
          onTap: () {
            AppSnackBar.showInfo(
              context,
              'أنواع السيارات تُدار من الإدارة ولا يمكن تعديلها هنا',
            );
          },
        );
      },
    );
  }
}
