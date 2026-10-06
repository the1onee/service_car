import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/phone.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart';

/// نص صف الهاتف في الحساب: الرقم بصيغة مقروءة، أو دعوة للإضافة إن كان فارغاً.
String profilePhoneLabel(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return AppStrings.addPhoneTitle;
  final e164 = normalizeIraqiPhone(trimmed);
  final shown =
      looksLikeIraqiMobile(e164) ? prettyIraqiPhone(e164) : trimmed;
  return '\u200E$shown';
}

/// يفتح حوار إضافة أو تعديل رقم الهاتف من صفحة الحساب.
/// يُرجع `true` بعد الحفظ الناجح.
Future<bool> showPhoneEditor(
  BuildContext context, {
  required String uid,
  required String currentPhone,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => _PhoneEditorDialog(
      uid: uid,
      currentPhone: currentPhone,
    ),
  );
  return saved == true;
}

class _PhoneEditorDialog extends StatefulWidget {
  const _PhoneEditorDialog({
    required this.uid,
    required this.currentPhone,
  });

  final String uid;
  final String currentPhone;

  @override
  State<_PhoneEditorDialog> createState() => _PhoneEditorDialogState();
}

class _PhoneEditorDialogState extends State<_PhoneEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phone;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final current = widget.currentPhone.trim();
    final e164 = normalizeIraqiPhone(current);
    final initial = looksLikeIraqiMobile(e164)
        ? prettyIraqiPhone(e164).replaceAll(' ', '')
        : current;
    _phone = TextEditingController(text: initial);
  }

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
      await AppScope.of(context).users.updatePhone(widget.uid, _phone.text);
      if (!mounted) return;
      Navigator.pop(context, true);
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
    final adding = widget.currentPhone.trim().isEmpty;
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.smartphone_rounded,
                size: 36,
                color: AppColors.petrol,
              ),
              const SizedBox(height: 12),
              Text(
                adding ? AppStrings.addPhoneTitle : 'تعديل رقم الهاتف',
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
              const SizedBox(height: 18),
              TextFormField(
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
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 13),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _busy ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
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
                    : const Text('حفظ الرقم'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
