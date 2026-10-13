import 'package:flutter/material.dart';
import 'package:barrr/core/app_brand.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/legal/privacy_policy.dart';
import 'package:url_launcher/url_launcher.dart';

/// عرض سياسة الخصوصية (قراءة فقط — من حسابي أو شاشة القبول).
class PrivacyViewScreen extends StatelessWidget {
  const PrivacyViewScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PrivacyViewScreen(),
      ),
    );
  }

  Future<void> _openPublicUrl() async {
    final uri = Uri.parse(PrivacyPolicy.publicUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(PrivacyPolicy.title),
        actions: [
          IconButton(
            tooltip: 'فتح النسخة على الموقع',
            onPressed: _openPublicUrl,
            icon: const Icon(Icons.open_in_new_rounded),
          ),
        ],
      ),
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
          const SizedBox(height: 4),
          Text(
            PrivacyPolicy.publicUrl,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.inkSoft,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            PrivacyPolicy.body.trim(),
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
