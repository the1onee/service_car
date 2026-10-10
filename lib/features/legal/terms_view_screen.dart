import 'package:flutter/material.dart';
import 'package:barrr/core/app_brand.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/legal/terms_of_use.dart';

/// عرض شروط الاستخدام (قراءة فقط — من حسابي أو رابط).
class TermsViewScreen extends StatelessWidget {
  const TermsViewScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const TermsViewScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppTerms.title)),
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
            AppTerms.body.trim(),
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
