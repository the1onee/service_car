import 'package:flutter/material.dart';
import 'package:barrr/features/technician/technician_home.dart';
import 'package:barrr/models/app_user.dart';

/// لوحة ورشة الزيوت: نفس دورة الزيارة المنزلية للفني (عرض → طريق → تنفيذ).
class OilWorkshopHome extends StatelessWidget {
  const OilWorkshopHome({super.key, required this.profile});

  final AppUser profile;

  @override
  Widget build(BuildContext context) {
    return TechnicianHome(profile: profile);
  }
}
