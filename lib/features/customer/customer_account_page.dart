import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/constants.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/jobs/job_present.dart';
import 'package:barrr/features/notifications/notifications_screen.dart';
import 'package:barrr/features/shared/address_map_picker.dart';
import 'package:barrr/features/shared/field_ui.dart';
import 'package:barrr/features/warranty/warranties_screen.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/job.dart';
import 'package:barrr/services/profile_photo_upload.dart';

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
  var _savingName = false;
  var _savingAddress = false;

  Future<void> _changePhoto() async {
    if (_uploadingPhoto) return;
    setState(() => _uploadingPhoto = true);
    final users = AppScope.of(context).users;
    final uid = widget.profile.id;
    try {
      final url = await ProfilePhotoUpload().pickAndUpload();
      await users.updateProfile(uid, photoUrl: url);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث صورة الملف الشخصي')),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('cancelled') || msg.contains('Canceled')) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر رفع الصورة: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: widget.profile.name);
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('تعديل الاسم'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'اسمك الظاهر في التطبيق',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              style: FilledButton.styleFrom(backgroundColor: AppColors.slate),
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (next == null || !mounted) return;
    if (next.isEmpty || next == widget.profile.name) return;

    final users = AppScope.of(context).users;
    final uid = widget.profile.id;
    setState(() => _savingName = true);
    try {
      await users.updateProfile(uid, name: next);
      try {
        await FirebaseAuth.instance.currentUser?.updateDisplayName(next);
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث الاسم')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ الاسم: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _editAddress() async {
    if (_savingAddress) return;
    final me = widget.profile;
    final initial = me.geo != null
        ? LatLng(me.geo!.latitude, me.geo!.longitude)
        : const LatLng(AppConstants.defaultLat, AppConstants.defaultLng);
    final picked = await pickAddressOnMap(
      context,
      initial: initial,
      title: 'تحديد عنوانك',
    );
    if (picked == null || !mounted) return;

    final controller = TextEditingController(
      text: picked.label.isNotEmpty
          ? picked.label
          : (me.address.trim().isEmpty ? '' : me.address),
    );
    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('تأكيد العنوان'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'اكتب العنوان بوضوح (حي، شارع، علامة دالة)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              style: FilledButton.styleFrom(backgroundColor: AppColors.slate),
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (confirmed == null || !mounted) return;
    if (confirmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب العنوان قبل الحفظ')),
      );
      return;
    }

    final users = AppScope.of(context).users;
    final uid = me.id;
    setState(() => _savingAddress = true);
    try {
      await users.setAddressAndGeo(
        uid,
        address: confirmed,
        geo: GeoPoint(picked.latLng.latitude, picked.latLng.longitude),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث العنوان')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ العنوان: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingAddress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.profile;
    final city = widget.city ?? me.cityNameAr;
    return ColoredBox(
      color: const Color(0xFFF8F9FF),
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
                  savingName: _savingName,
                  onChangePhoto: _changePhoto,
                  onEditName: _editName,
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 18),
                const Text(
                  'الحساب',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                _MenuCard(
                  children: [
                    _MenuTile(
                      icon: Icons.verified_user_outlined,
                      title: 'سجل الضمانات',
                      subtitle: 'المطالبات والتغطية السارية',
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
                      icon: Icons.assignment_outlined,
                      title: 'الطلبات',
                      subtitle: 'عرض وتتبع طلباتك',
                      onTap: widget.onOpenOrders,
                    ),
                    const Divider(height: 1),
                    _MenuTile(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'المحفظة والمدفوعات',
                      subtitle: 'سجل المدفوعات النقدية',
                      onTap: widget.onOpenWallet,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: AppTheme.cardShadow(),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 18, color: AppColors.amberDeep),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'العنوان',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _savingAddress ? null : _editAddress,
                            icon: _savingAddress
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.edit_location_alt,
                                    size: 16),
                            label: Text(
                              _savingAddress ? 'جاري الحفظ…' : 'تعديل',
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.amberDeep,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        me.address.trim().isEmpty
                            ? 'لم يُحدد عنوان بعد — اضغط تعديل واختر موقعك على الخريطة'
                            : me.address,
                        style: const TextStyle(
                          color: AppColors.inkSoft,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
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
    required this.savingName,
    required this.onChangePhoto,
    required this.onEditName,
  });

  final AppUser profile;
  final bool uploadingPhoto;
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
                      width: 88,
                      height: 88,
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
                              : Image.network(
                                  photo,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Center(
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
                        color: AppColors.amber,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.slate, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt,
                          size: 15, color: AppColors.ink),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                profile.name.trim().isEmpty ? 'بدون اسم' : profile.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                profile.phone,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  color: Color(0xFFBEC6E0),
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
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
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: savingName ? null : onEditName,
                    icon: savingName
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.amber,
                            ),
                          )
                        : const Icon(Icons.edit_outlined, size: 16),
                    label: Text(savingName ? 'جاري الحفظ…' : 'تعديل الاسم'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.amber,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: uploadingPhoto ? null : onChangePhoto,
                    icon: const Icon(Icons.photo_camera_outlined, size: 16),
                    label: const Text('تغيير الصورة'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.amber,
                      visualDensity: VisualDensity.compact,
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.amberDeep),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow(),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.white,
        child: Column(children: children),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.recessed,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.slate, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
      ),
      trailing: const Icon(Icons.chevron_left, color: AppColors.inkSoft),
    );
  }
}
