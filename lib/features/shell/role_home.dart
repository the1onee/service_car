import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/features/admin/admin_home.dart';
import 'package:barrr/features/customer/customer_home.dart';
import 'package:barrr/features/oil_workshop/oil_workshop_home.dart';
import 'package:barrr/features/paint_shop/paint_shop_home.dart';
import 'package:barrr/features/technician/technician_home.dart';
import 'package:barrr/features/workshop/workshop_home.dart';
import 'package:barrr/models/app_user.dart';

/// مفتاح واجهة الدور — يُستخدم في الاختبارات والـ ValueKey.
String roleHomeKeyFor(AppUser profile) {
  if (profile.isAdmin) return 'home-admin';
  if (profile.isOilWorkshop) return 'home-oil-workshop';
  if (profile.isPaintShop) return 'home-paint-shop';
  if (profile.isWorkshop) return 'home-workshop';
  if (profile.isTechnician) return 'home-technician';
  return 'home-customer';
}

class RoleHome extends StatefulWidget {
  const RoleHome({
    super.key,
    required this.profile,
    this.homeBuilder,
  });

  final AppUser profile;

  /// للاختبارات: يستبدل شاشات الأدوار الثقيلة بواجهة خفيفة.
  final Widget Function(AppUser profile, String roleKey)? homeBuilder;

  @override
  State<RoleHome> createState() => _RoleHomeState();
}

class _RoleHomeState extends State<RoleHome> {
  var _booted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_booted) return;
    _booted = true;
    final scope = AppScope.of(context);
    final profile = widget.profile;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      scope.fcm.init(profile.id);
      // الكتالوج يُدار من لوحة التحكم، والقواعد تسمح بالكتابة للأدمن فقط.
      if (!profile.isAdmin) return;
      // بدون Firebase (اختبارات الوحدة) لا نلمس Firestore.
      if (Firebase.apps.isEmpty) return;
      try {
        scope.users.seedServicesIfNeeded();
        scope.users.syncSeedVehicleTypes().catchError((Object e) {
          debugPrint('syncSeedVehicleTypes: $e');
        });
      } catch (e) {
        debugPrint('admin seed skipped: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final roleKey = roleHomeKeyFor(widget.profile);
    final builder = widget.homeBuilder;
    if (builder != null) {
      return KeyedSubtree(
        key: ValueKey(roleKey),
        child: builder(widget.profile, roleKey),
      );
    }
    if (widget.profile.isAdmin) {
      return KeyedSubtree(
        key: ValueKey(roleKey),
        child: AdminHome(profile: widget.profile),
      );
    }
    if (widget.profile.isOilWorkshop) {
      return KeyedSubtree(
        key: ValueKey(roleKey),
        child: OilWorkshopHome(profile: widget.profile),
      );
    }
    if (widget.profile.isPaintShop) {
      return KeyedSubtree(
        key: ValueKey(roleKey),
        child: PaintShopHome(profile: widget.profile),
      );
    }
    if (widget.profile.isWorkshop) {
      return KeyedSubtree(
        key: ValueKey(roleKey),
        child: WorkshopHome(profile: widget.profile),
      );
    }
    if (widget.profile.isTechnician) {
      return KeyedSubtree(
        key: ValueKey(roleKey),
        child: TechnicianHome(profile: widget.profile),
      );
    }
    return KeyedSubtree(
      key: ValueKey(roleKey),
      child: CustomerHome(profile: widget.profile),
    );
  }
}
