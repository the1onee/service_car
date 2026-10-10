import 'package:flutter/material.dart';
import 'package:barrr/core/app_brand.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/features/legal/terms_view_screen.dart';
import 'package:barrr/legal/terms_of_use.dart';
import 'package:barrr/models/app_user.dart';

/// قبول شروط الاستخدام مرة واحدة (أو عند رفع رقم النسخة).
class TermsAcceptScreen extends StatefulWidget {
  const TermsAcceptScreen({super.key, required this.profile});

  final AppUser profile;

  @override
  State<TermsAcceptScreen> createState() => _TermsAcceptScreenState();
}

class _TermsAcceptScreenState extends State<TermsAcceptScreen> {
  var _checked = false;
  var _busy = false;
  String? _error;

  Future<void> _accept() async {
    if (!_checked || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).users.acceptTerms(widget.profile.id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'تعذر حفظ الموافقة. تحقق من الاتصال وحاول مجدداً.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Text(
                  AppBrand.appName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        AppTerms.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            AppTerms.body.trim(),
                            style: const TextStyle(
                              height: 1.6,
                              color: AppColors.inkSoft,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => TermsViewScreen.open(context),
                        child: const Text('فتح الشروط في صفحة كاملة'),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _checked,
                        onChanged: _busy
                            ? null
                            : (v) => setState(() => _checked = v == true),
                        title: const Text(
                          'أوافق على شروط استخدام التطبيق',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      if (_error != null) ...[
                        Text(
                          _error!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                        const SizedBox(height: 8),
                      ],
                      FilledButton(
                        onPressed: (_checked && !_busy) ? _accept : null,
                        child: _busy
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('متابعة'),
                      ),
                    ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
