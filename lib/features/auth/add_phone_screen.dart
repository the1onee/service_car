import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/phone.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/models/app_user.dart';

/// تُعرض بعد التسجيل عبر Google/البريد إذا لم يُحفظ رقم هاتف بعد.
class AddPhoneScreen extends StatefulWidget {
  const AddPhoneScreen({super.key, required this.profile});

  final AppUser profile;

  @override
  State<AddPhoneScreen> createState() => _AddPhoneScreenState();
}

class _AddPhoneScreenState extends State<AddPhoneScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).users.updatePhone(
            widget.profile.id,
            _phone.text,
          );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.code == 'phone-already-registered'
            ? 'هذا الرقم مستخدم لحساب آخر.'
            : (e.message ?? 'تعذّر حفظ الرقم.');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is FormatException
          ? (e.message)
          : 'تعذّر حفظ الرقم. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 24 + bottomInset),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: AppTheme.softShadow(opacity: 0.16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.smartphone_rounded,
                        size: 42,
                        color: AppColors.petrol,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        AppStrings.addPhoneTitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        AppStrings.addPhoneHint,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.5,
                          color: AppColors.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Form(
                        key: _formKey,
                        child: TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.left,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9+\u0660-\u0669 ]'),
                            ),
                            LengthLimitingTextInputFormatter(16),
                          ],
                          onFieldSubmitted: (_) => _save(),
                          decoration: const InputDecoration(
                            labelText: AppStrings.phone,
                            hintText: '07701234567',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          validator: (v) {
                            final e164 = normalizeIraqiPhone(v ?? '');
                            if (!looksLikeIraqiMobile(e164)) {
                              return 'أدخل رقماً عراقياً صالحاً. مثال: 07701234567';
                            }
                            return null;
                          },
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _busy ? null : _save,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: AppColors.petrol,
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(AppStrings.savePhone),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
