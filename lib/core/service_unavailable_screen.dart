import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:barrr/core/app_brand.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart';

/// عند فشل تهيئة Firebase — رسالة للمستخدم النهائي.
class ServiceUnavailableScreen extends StatelessWidget {
  const ServiceUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    AppBrand.logoAsset,
                    height: 72,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.car_repair_outlined,
                      size: 72,
                      color: AppColors.slate,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'تعذّر الاتصال بالخدمة',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'تحقق من اتصال الإنترنت أو حدّث التطبيق من المتجر. '
                    'إن استمرت المشكلة تواصل مع الدعم.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _callSupport,
                    icon: const Icon(Icons.phone_outlined),
                    label: Text(AppStrings.callSupport),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _callSupport() async {
    final uri = Uri(scheme: 'tel', path: AppStrings.supportPhone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
