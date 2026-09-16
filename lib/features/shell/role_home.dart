import 'package:flutter/material.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/features/admin/admin_home.dart';
import 'package:barrr/features/customer/customer_home.dart';
import 'package:barrr/features/technician/technician_home.dart';
import 'package:barrr/models/app_user.dart';

class RoleHome extends StatefulWidget {
  const RoleHome({super.key, required this.profile});

  final AppUser profile;

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
    scope.fcm.init(widget.profile.id);
    scope.users.seedServicesIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.profile.isAdmin) {
      return AdminHome(profile: widget.profile);
    }
    if (widget.profile.isTechnician) {
      return TechnicianHome(profile: widget.profile);
    }
    return CustomerHome(profile: widget.profile);
  }
}
