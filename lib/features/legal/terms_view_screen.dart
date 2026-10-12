import 'package:flutter/material.dart';
import 'package:barrr/core/app_brand.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/legal/role_terms.dart';
import 'package:barrr/models/app_user.dart';

/// عرض شروط الاستخدام (قراءة فقط — من حسابي أو رابط).
class TermsViewScreen extends StatelessWidget {
  const TermsViewScreen({super.key, required this.role});

  final UserRole role;

  static void open(BuildContext context, {UserRole role = UserRole.customer}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TermsViewScreen(role: role),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(RoleTerms.titleFor(role))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            AppBrand.appName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            RoleTerms.bodyFor(role).trim(),
            style: const TextStyle(
              height: 1.65,
              fontSize: 15,
              color: AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}
