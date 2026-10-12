import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/core/user_error.dart';

/// شاشة بديلة عند فشل بناء ويدجت — للإRelease فقط.
class AppErrorWidget extends StatelessWidget {
  const AppErrorWidget({super.key, required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    logUserError(details.exception, details.stack, 'error_widget');
    return Material(
      color: AppColors.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                  const SizedBox(height: 16),
                  Text(
                    'حدث خطأ غير متوقع',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'أعد فتح التطبيق. إن استمرت المشكلة تواصل مع الدعم.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
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

void configureProductionErrorPresentation() {
  if (kReleaseMode) {
    ErrorWidget.builder = (details) => AppErrorWidget(details: details);
  }
}
