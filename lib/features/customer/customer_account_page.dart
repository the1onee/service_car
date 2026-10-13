import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/features/auth/add_phone_screen.dart';
import 'package:barrr/features/shared/account_shared.dart';
import 'package:barrr/features/jobs/job_present.dart';
import 'package:barrr/features/notifications/notifications_screen.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/core/app_brand.dart';
import 'package:barrr/features/legal/privacy_view_screen.dart';
import 'package:barrr/features/legal/terms_view_screen.dart';
import 'package:barrr/features/support/support_screen.dart';
import 'package:barrr/features/warranty/warranties_screen.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/job.dart';

/// صفحة حساب العميل — تعديل الاسم وصورة البروفايل.
class CustomerAccountPage extends StatefulWidget {
  const CustomerAccountPage({
    super.key,
    required this.profile,
    required this.jobs,
    this.city,
    required this.onOpenOrders,
    required this.onOpenWallet,
  });

  final AppUser profile;
  final Stream<List<Job>> jobs;
  final String? city;
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenWallet;

  @override
  State<CustomerAccountPage> createState() => _CustomerAccountPageState();
}

class _CustomerAccountPageState extends State<CustomerAccountPage> {
  var _uploadingPhoto = false;
  var _photoSaved = false;
  var _savingName = false;
  var _savingAddress = false;
  var _locationPrompted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePromptLocation());
  }

  @override
  void didUpdateWidget(covariant CustomerAccountPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.geo == null && widget.profile.geo != null) {
      _locationPrompted = true;
    }
    if (!_locationPrompted && widget.profile.geo == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybePromptLocation());
    }
  }

  void _maybePromptLocation() {
    if (!mounted || _locationPrompted || _savingAddress) return;
    if (widget.profile.geo != null) {
      _locationPrompted = true;
      return;
    }
    _locationPrompted = true;
    _editAddress();
  }

  Future<void> _changePhoto() async {
    if (_uploadingPhoto) return;
    setState(() => _uploadingPhoto = true);
    final url = await AccountActions.changePhoto(context, uid: widget.profile.id);
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
      uid: widget.profile.id,
      currentName: widget.profile.name,
    );
    if (mounted) setState(() => _savingName = false);
  }

  void _showAbout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppBrand.appName),
        content: SingleChildScrollView(
          child: Text(
            '${AppBrand.tagline}\n\n${AppBrand.aboutBlurb}\n\n'
            'الدعم: ${AppBrand.supportPhone}',
            style: const TextStyle(height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  Future<void> _editAddress() async {
    if (_savingAddress) return;
    final me = widget.profile;
    final LatLng? initial = me.geo != null
        ? LatLng(me.geo!.latitude, me.geo!.longitude)
        : null;
    setState(() => _savingAddress = true);
    await AccountActions.editAddress(
      context,
      uid: me.id,
      currentGeo: initial,
      currentAddress: me.address,
      title: 'تحديد عنوانك',
    );
    if (mounted) setState(() => _savingAddress = false);
  }

  Future<void> _editPhone() async {
    await AccountActions.editPhone(
      context,
      uid: widget.profile.id,
      currentPhone: widget.profile.phone,
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.profile;
    final city = widget.city ?? me.cityNameAr;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          FieldTopBar(
            city: city.isEmpty ? null : city,
            caption: 'حسابي',
            trailing: NotificationsBellButton(uid: me.id),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _ProfileHero(
                  profile: me,
                  uploadingPhoto: _uploadingPhoto,
                  photoSaved: _photoSaved,
                  savingName: _savingName,
                  onChangePhoto: _changePhoto,
                  onEditName: _editName,
                ),
                const SizedBox(height: 16),
                StreamBuilder<List<Job>>(
                  stream: widget.jobs,
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'تعذر تحميل إحصائيات الطلبات',
                          style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
                        ),
                      );
                    }
                    final rows = snap.data ?? const <Job>[];
                    final done = rows.where(jobIsDone).length;
                    final covered =
                        rows.where((j) => j.warranty.enabled).length;
                    return Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.check_circle_outline,
                            title: 'طلبات مكتملة',
                            value: '$done',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.verified_user_outlined,
                            title: 'وثائق ضمان',
                            value: '$covered',
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                _MenuCard(
                  children: [
                    _MenuTile(
                      icon: Icons.assignment_outlined,
                      title: 'الطلبات',
                      onTap: widget.onOpenOrders,
                    ),
                    const Divider(height: 1),
                    _MenuTile(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'المحفظة',
                      onTap: widget.onOpenWallet,
                    ),
                    const Divider(height: 1),
                    _MenuTile(
                      icon: Icons.verified_user_outlined,
                      title: 'الضمان',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => WarrantiesScreen(
                              stream: AppScope.of(context)
                                  .jobs
                                  .watchRecentForCustomer(me.id),
                              profile: me,
                            ),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    _MenuTile(
                      icon: Icons.phone_outlined,
                      title: AppStrings.phone,
                      subtitle: profilePhoneLabel(me.phone),
                      onTap: _editPhone,
                    ),
                    const Divider(height: 1),
                    _MenuTile(
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
                    _MenuTile(
                      icon: Icons.info_outline_rounded,
                      title: 'عن التطبيق',
                      subtitle: AppBrand.appName,
                      onTap: () => _showAbout(context),
                    ),
                    const Divider(height: 1),
                    _MenuTile(
                      icon: Icons.description_outlined,
                      title: 'شروط الاستخدام',
                      onTap: () => TermsViewScreen.open(
                        context,
                        role: me.role,
                      ),
                    ),
                    const Divider(height: 1),
                    _MenuTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'سياسة الخصوصية',
                      onTap: () => PrivacyViewScreen.open(context),
                    ),
                    const Divider(height: 1),
                    _MenuTile(
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

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.profile,
    required this.uploadingPhoto,
    required this.photoSaved,
    required this.savingName,
    required this.onChangePhoto,
    required this.onEditName,
  });

  final AppUser profile;
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
                                  placeholder: (context, url) => const Center(child: CircularProgressIndicator()),

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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'عميل',
                  style: TextStyle(
                    color: Color(0xFFFFDDB8),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

typedef _StatCard = AccountStatCard;
typedef _MenuCard = AccountMenuCard;
typedef _MenuTile = AccountTile;

