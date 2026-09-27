import 'package:flutter/material.dart';
import 'package:barrr/features/technician/technician_home.dart';
import 'package:barrr/models/app_user.dart';

/// لوحة ورشة الدهان: نفس دورة العروض والتنفيذ للفني.
class PaintShopHome extends StatelessWidget {
  const PaintShopHome({super.key, required this.profile});

  final AppUser profile;

  @override
  Widget build(BuildContext context) {
    return TechnicianHome(profile: profile);
  }
}
