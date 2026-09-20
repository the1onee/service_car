import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/phone.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/data/service_catalog.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/services/auth_service.dart';

enum _Stage { login, register, otp }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _loginForm = GlobalKey<FormState>();
  final _registerForm = GlobalKey<FormState>();

  final _loginPhone = TextEditingController();
  final _loginPassword = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _address = TextEditingController();
  final _idCard = TextEditingController();
  final _otp = TextEditingController();

  _Stage _stage = _Stage.login;
  UserRole _registerRole = UserRole.customer;
  final Set<String> _skills = {};
  OtpPurpose _purpose = OtpPurpose.register;
  bool _hidePassword = true;
  bool _hideConfirm = true;
  bool _busy = false;
  String? _error;

  Timer? _resendTimer;
  int _resendIn = 0;

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in [
      _loginPhone,
      _loginPassword,
      _name,
      _phone,
      _password,
      _confirm,
      _address,
      _idCard,
      _otp,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------- الإجراءات

  AuthService get _auth => AppScope.of(context).auth;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _login() {
    if (!(_loginForm.currentState?.validate() ?? false)) return;
    _run(() => _auth.signIn(
          phone: _loginPhone.text,
          password: _loginPassword.text,
        ));
  }

  void _startRegistration() {
    if (!(_registerForm.currentState?.validate() ?? false)) return;
    _run(() async {
      await _auth.startRegistration(
        phone: _phone.text,
        password: _password.text,
      );
      if (!mounted) return;
      setState(() {
        _purpose = OtpPurpose.register;
        _stage = _Stage.otp;
        _otp.clear();
      });
      _startResendCountdown();
    });
  }

  void _startPasswordReset(String phone) {
    _run(() async {
      await _auth.sendResetOtp(phone);
      if (!mounted) return;
      setState(() {
        _purpose = OtpPurpose.resetPassword;
        _stage = _Stage.otp;
        _otp.clear();
        _password.clear();
      });
      _startResendCountdown();
    });
  }

  void _submitOtp() {
    if (_otp.text.trim().length < 6) {
      setState(() => _error = 'أدخل الرمز المكوّن من ٦ أرقام.');
      return;
    }
    _run(() async {
      if (_purpose == OtpPurpose.register) {
        await _auth.completeRegistration(
          smsCode: _otp.text,
          name: _name.text,
          address: _address.text,
          role: _registerRole,
          idCard: _idCard.text,
          serviceIds: _skills.toList(),
        );
        return;
      }
      final newPassword = await _askNewPassword();
      if (newPassword == null) return;
      await _auth.resetPassword(
        smsCode: _otp.text,
        newPassword: newPassword,
      );
    });
  }

  void _resendOtp() {
    if (_resendIn > 0) return;
    _run(() async {
      await _auth.resendOtp(_purpose);
      _startResendCountdown();
    });
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn -= 1);
      if (_resendIn <= 0) t.cancel();
    });
  }

  void _backFromOtp() {
    _resendTimer?.cancel();
    if (_purpose == OtpPurpose.register) _auth.cancelRegistration();
    setState(() {
      _resendIn = 0;
      _error = null;
      _stage = _purpose == OtpPurpose.register ? _Stage.register : _Stage.login;
    });
  }

  Future<String?> _askNewPassword() => showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const _NewPasswordSheet(),
      );

  Future<void> _openForgotPassword() async {
    final phone = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ForgotPasswordSheet(initialPhone: _loginPhone.text),
    );
    if (phone != null && mounted) _startPasswordReset(phone);
  }

  String _friendlyError(Object e) {
    if (e is! FirebaseAuthException) return 'تعذر إكمال العملية. حاول مرة أخرى.';
    switch (e.code) {
      case 'invalid-phone-number':
        return 'رقم الهاتف غير صالح. استخدم صيغة 07701234567';
      case 'invalid-credential':
      case 'invalid-email':
      case 'user-not-found':
      case 'wrong-password':
        return 'رقم الهاتف أو كلمة المرور غير صحيحة.';
      case 'user-disabled':
        return 'هذا الحساب موقوف. راجع الإدارة.';
      case 'phone-already-registered':
        return 'هذا الرقم مسجّل مسبقاً. سجّل الدخول بكلمة المرور.';
      case 'invalid-verification-code':
        return 'رمز التحقق غير صحيح.';
      case 'session-expired':
        return 'انتهت صلاحية الرمز. اطلب رمزاً جديداً.';
      case 'too-many-requests':
        return 'محاولات كثيرة. انتظر قليلاً ثم أعد المحاولة.';
      case 'quota-exceeded':
        return 'تم تجاوز حد رسائل التحقق اليوم. حاول لاحقاً.';
      case 'operation-not-allowed':
        return 'مزوّد الدخول غير مفعّل في Firebase.';
      case 'network-request-failed':
        return 'لا يوجد اتصال بالإنترنت.';
      case 'weak-password':
        return 'كلمة المرور ضعيفة، استخدم ٦ أحرف على الأقل.';
      default:
        // بعض أخطاء المنصّة تعيد رسالة عامة مثل "Error"، فنعرض بديلاً مفهوماً.
        final message = e.message?.trim() ?? '';
        if (message.length < 12) {
          return 'تعذر إكمال العملية (${e.code}). حاول مرة أخرى.';
        }
        return message;
    }
  }

  // ------------------------------------------------------------------ الواجهة

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      body: Stack(
        children: [
          const _AuthBackdrop(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                padding: EdgeInsets.only(bottom: 24 + bottomInset),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight - 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 28),
                            const _BrandHeader(),
                            const SizedBox(height: 26),
                            _card(),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
        boxShadow: AppTheme.softShadow(opacity: 0.14),
      ),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: switch (_stage) {
            _Stage.login => _loginView(),
            _Stage.register => _registerView(),
            _Stage.otp => _otpView(),
          },
        ),
      ),
    );
  }

  Widget _loginView() {
    return Column(
      key: const ValueKey('login'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StageSwitch(
          isLogin: true,
          onChanged: (login) => setState(() {
            _stage = login ? _Stage.login : _Stage.register;
            _error = null;
          }),
        ),
        const SizedBox(height: 22),
        const _SectionTitle(
          title: AppStrings.welcomeBack,
          subtitle: AppStrings.loginHint,
        ),
        const SizedBox(height: 18),
        Form(
          key: _loginForm,
          child: Column(
            children: [
              _PhoneField(controller: _loginPhone, onSubmitted: (_) => _login()),
              const SizedBox(height: 14),
              _PasswordField(
                controller: _loginPassword,
                label: AppStrings.password,
                obscure: _hidePassword,
                autofillHint: AutofillHints.password,
                onToggle: () => setState(() => _hidePassword = !_hidePassword),
                onSubmitted: (_) => _login(),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: _busy ? null : _openForgotPassword,
                  child: const Text(AppStrings.forgotPassword),
                ),
              ),
            ],
          ),
        ),
        _errorBanner(),
        const SizedBox(height: 6),
        _GradientButton(
          label: AppStrings.login,
          icon: Icons.login_rounded,
          busy: _busy,
          onPressed: _login,
        ),
        const SizedBox(height: 14),
        _FooterLink(
          question: AppStrings.noAccount,
          action: AppStrings.register,
          onTap: () => setState(() {
            _stage = _Stage.register;
            _error = null;
          }),
        ),
      ],
    );
  }

  Widget _registerView() {
    return Column(
      key: const ValueKey('register'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StageSwitch(
          isLogin: false,
          onChanged: (login) => setState(() {
            _stage = login ? _Stage.login : _Stage.register;
            _error = null;
          }),
        ),
        const SizedBox(height: 22),
        const _SectionTitle(
          title: AppStrings.registerTitle,
          subtitle: AppStrings.registerHint,
        ),
        const SizedBox(height: 14),
        _RolePicker(
          role: _registerRole,
          onChanged: (role) => setState(() {
            _registerRole = role;
            _error = null;
          }),
        ),
        const SizedBox(height: 12),
        _RoleNotice(role: _registerRole),
        const SizedBox(height: 16),
        Form(
          key: _registerForm,
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(
                  labelText: AppStrings.name,
                  hintText: 'مثال: علي حسن الجابري',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (v) {
                  final name = (v ?? '').trim();
                  if (name.length < 3) return 'أدخل الاسم الكامل.';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _PhoneField(controller: _phone),
              const SizedBox(height: 14),
              _PasswordField(
                controller: _password,
                label: AppStrings.password,
                obscure: _hidePassword,
                autofillHint: AutofillHints.newPassword,
                onToggle: () => setState(() => _hidePassword = !_hidePassword),
                validator: (v) {
                  if ((v ?? '').length < 6) return 'استخدم ٦ أحرف أو أرقام على الأقل.';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _PasswordField(
                controller: _confirm,
                label: AppStrings.confirmPassword,
                obscure: _hideConfirm,
                autofillHint: AutofillHints.newPassword,
                onToggle: () => setState(() => _hideConfirm = !_hideConfirm),
                validator: (v) {
                  if (v != _password.text) return 'كلمتا المرور غير متطابقتين.';
                  return null;
                },
              ),
              if (_registerRole == UserRole.technician) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _idCard,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: AppStrings.idCard,
                    hintText: AppStrings.optional,
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              TextFormField(
                controller: _address,
                maxLines: 2,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.fullStreetAddress],
                decoration: const InputDecoration(
                  labelText: AppStrings.address,
                  hintText: 'المدينة، الحي، أقرب نقطة دالة — اختياري',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              if (_registerRole == UserRole.technician) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    '${AppStrings.skills} (${AppStrings.optional})',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in seedServices)
                      FilterChip(
                        label: Text(s.titleAr),
                        selected: _skills.contains(s.id),
                        onSelected: (on) => setState(() {
                          if (on) {
                            _skills.add(s.id);
                          } else {
                            _skills.remove(s.id);
                          }
                        }),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        _errorBanner(),
        const SizedBox(height: 20),
        _GradientButton(
          label: AppStrings.continueLabel,
          icon: Icons.arrow_forward_rounded,
          busy: _busy,
          onPressed: _startRegistration,
        ),
        const SizedBox(height: 14),
        _FooterLink(
          question: AppStrings.haveAccount,
          action: AppStrings.login,
          onTap: () => setState(() {
            _stage = _Stage.login;
            _error = null;
          }),
        ),
      ],
    );
  }

  Widget _otpView() {
    final phone = _auth.pendingPhone ?? '';
    return Column(
      key: const ValueKey('otp'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: _busy ? null : _backFromOtp,
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: AppStrings.changePhone,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.canvas,
                foregroundColor: AppColors.ink,
              ),
            ),
            const Spacer(),
            const _Pill(
              icon: Icons.verified_user_outlined,
              label: 'تحقق آمن',
              color: AppColors.azure,
              tint: AppColors.azureTint,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionTitle(
          title: _purpose == OtpPurpose.register
              ? AppStrings.verifyPhone
              : AppStrings.resetPassword,
          subtitle: AppStrings.otpSentTo,
        ),
        const SizedBox(height: 6),
        Text(
          prettyIraqiPhone(phone),
          textDirection: TextDirection.ltr,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: AppColors.petrol,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 24),
        _OtpBoxes(controller: _otp, onCompleted: _submitOtp),
        _errorBanner(),
        const SizedBox(height: 22),
        _GradientButton(
          label: AppStrings.verifyOtp,
          icon: Icons.check_rounded,
          busy: _busy,
          onPressed: _submitOtp,
        ),
        const SizedBox(height: 10),
        Center(
          child: _resendIn > 0
              ? Text(
                  '${AppStrings.resendIn} $_resendIn ثانية',
                  style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
                )
              : TextButton.icon(
                  onPressed: _busy ? null : _resendOtp,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(AppStrings.resendOtp),
                ),
        ),
      ],
    );
  }

  Widget _errorBanner() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topCenter,
      child: _error == null
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.dangerTint,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.danger, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFF7A1F26),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ------------------------------------------------------------ مكوّنات الواجهة

/// خلفية متدرّجة مع أشكال ناعمة تعطي عمقاً للشاشة.
class _AuthBackdrop extends StatelessWidget {
  const _AuthBackdrop();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0C5C51), Color(0xFF117F6B), AppColors.canvas],
            stops: [0, 0.32, 0.66],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -70,
              right: -50,
              child: _Blob(size: 210, color: Colors.white.withValues(alpha: 0.10)),
            ),
            Positioned(
              top: 120,
              left: -70,
              child: _Blob(size: 180, color: AppColors.amber.withValues(alpha: 0.16)),
            ),
            Positioned(
              top: 40,
              left: 90,
              child: _Blob(size: 70, color: Colors.white.withValues(alpha: 0.08)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 76,
          width: 76,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: Center(
            child: Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                gradient: AppTheme.amberGradient,
                borderRadius: BorderRadius.circular(17),
                boxShadow: AppTheme.softShadow(
                  color: AppColors.amber,
                  opacity: 0.45,
                ),
              ),
              child: const Icon(Icons.car_repair_rounded,
                  color: AppColors.ink, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          AppStrings.appName,
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          AppStrings.tagline,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

/// مبدّل بين تسجيل الدخول وإنشاء الحساب مع مؤشّر منزلق.
class _StageSwitch extends StatelessWidget {
  const _StageSwitch({required this.isLogin, required this.onChanged});

  final bool isLogin;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment:
                isLogin ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppTheme.softShadow(
                    color: AppColors.petrol,
                    opacity: 0.28,
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              _tab(AppStrings.login, isLogin, () => onChanged(true)),
              _tab(AppStrings.register, !isLogin, () => onChanged(false)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: active ? Colors.white : AppColors.inkSoft,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13.5,
            color: AppColors.inkSoft,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _RolePicker extends StatelessWidget {
  const _RolePicker({required this.role, required this.onChanged});

  final UserRole role;
  final ValueChanged<UserRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _roleTile(
            label: AppStrings.customer,
            selected: role == UserRole.customer,
            onTap: () => onChanged(UserRole.customer),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _roleTile(
            label: AppStrings.technician,
            selected: role == UserRole.technician,
            onTap: () => onChanged(UserRole.technician),
          ),
        ),
      ],
    );
  }

  Widget _roleTile({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.petrolTint : AppColors.canvas,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.petrol : AppColors.outline,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: selected ? AppColors.petrolDark : AppColors.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleNotice extends StatelessWidget {
  const _RoleNotice({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final isTech = role == UserRole.technician;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isTech ? AppColors.amberTint : AppColors.petrolTint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: isTech ? AppColors.amber : AppColors.petrol,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isTech ? Icons.handyman_rounded : Icons.person_rounded,
              color: isTech ? AppColors.ink : Colors.white,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isTech
                  ? AppStrings.technicianAccountNote
                  : AppStrings.customerAccountNote,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: isTech ? AppColors.ink : AppColors.petrolDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.color,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller, this.onSubmitted});

  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.telephoneNumber],
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+\u0660-\u0669 ]')),
        LengthLimitingTextInputFormatter(16),
      ],
      onFieldSubmitted: onSubmitted,
      decoration: const InputDecoration(
        labelText: AppStrings.phone,
        hintText: '07701234567',
        prefixIcon: Icon(Icons.smartphone_rounded),
        suffixIcon: Padding(
          padding: EdgeInsetsDirectional.only(end: 14),
          child: Center(
            widthFactor: 1,
            child: Text(
              '964+',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.inkSoft,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
      validator: (v) {
        if (!looksLikeIraqiMobile(normalizeIraqiPhone(v ?? ''))) {
          return 'أدخل رقماً عراقياً صحيحاً مثل 07701234567';
        }
        return null;
      },
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    required this.autofillHint,
    this.validator,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final String autofillHint;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      textInputAction: TextInputAction.next,
      autofillHints: [autofillHint],
      onFieldSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        hintText: '••••••••',
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: 20,
          ),
        ),
      ),
      validator: validator ??
          (v) => (v ?? '').isEmpty ? 'أدخل كلمة المرور.' : null,
    );
  }
}

/// ستة مربعات لرمز التحقق تعمل بحقل واحد مخفي يدعم اللصق والتعبئة التلقائية.
class _OtpBoxes extends StatefulWidget {
  const _OtpBoxes({required this.controller, required this.onCompleted});

  final TextEditingController controller;
  final VoidCallback onCompleted;

  @override
  State<_OtpBoxes> createState() => _OtpBoxesState();
}

class _OtpBoxesState extends State<_OtpBoxes> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _focus.addListener(_repaint);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _repaint() {
    if (mounted) setState(() {});
  }

  void _onChanged() {
    _repaint();
    if (widget.controller.text.length == 6) {
      _focus.unfocus();
      widget.onCompleted();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focus.removeListener(_repaint);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;
    return GestureDetector(
      onTap: _focus.requestFocus,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < 6; i++)
                  _box(
                    digit: i < code.length ? code[i] : '',
                    active: _focus.hasFocus && i == code.length,
                  ),
              ],
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                keyboardType: TextInputType.number,
                maxLength: 6,
                showCursor: false,
                enableInteractiveSelection: false,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(counterText: ''),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _box({required String digit, required bool active}) {
    final filled = digit.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 58,
      width: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? AppColors.petrolTint : const Color(0xFFF7FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active
              ? AppColors.petrol
              : filled
                  ? AppColors.petrol.withValues(alpha: 0.35)
                  : AppColors.outline,
          width: active ? 1.8 : 1,
        ),
      ),
      child: Text(
        digit,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.petrolDark,
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.busy,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: busy ? 0.7 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppTheme.brandGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.softShadow(color: AppColors.petrol, opacity: 0.32),
        ),
        child: FilledButton(
          onPressed: busy ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white,
            shadowColor: Colors.transparent,
            elevation: 0,
          ),
          child: busy
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label),
                    if (icon != null) ...[
                      const SizedBox(width: 8),
                      Icon(icon, size: 19),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({
    required this.question,
    required this.action,
    required this.onTap,
  });

  final String question;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          question,
          style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
        ),
        TextButton(onPressed: onTap, child: Text(action)),
      ],
    );
  }
}

/// طلب رقم الهاتف لبدء استعادة كلمة المرور.
class _ForgotPasswordSheet extends StatefulWidget {
  const _ForgotPasswordSheet({required this.initialPhone});

  final String initialPhone;

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  final _form = GlobalKey<FormState>();
  late final _phone = TextEditingController(text: widget.initialPhone);

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: AppStrings.resetPassword,
      subtitle: 'سنرسل رمز تحقق إلى رقمك لتعيين كلمة مرور جديدة.',
      child: Form(
        key: _form,
        child: Column(
          children: [
            _PhoneField(controller: _phone),
            const SizedBox(height: 20),
            _GradientButton(
              label: 'إرسال الرمز',
              icon: Icons.send_rounded,
              busy: false,
              onPressed: () {
                if (_form.currentState?.validate() ?? false) {
                  Navigator.pop(context, _phone.text);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// تعيين كلمة المرور الجديدة بعد نجاح التحقق.
class _NewPasswordSheet extends StatefulWidget {
  const _NewPasswordSheet();

  @override
  State<_NewPasswordSheet> createState() => _NewPasswordSheetState();
}

class _NewPasswordSheetState extends State<_NewPasswordSheet> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _hide = true;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: AppStrings.newPassword,
      subtitle: 'اختر كلمة مرور جديدة لحسابك.',
      child: Form(
        key: _form,
        child: Column(
          children: [
            _PasswordField(
              controller: _password,
              label: AppStrings.newPassword,
              obscure: _hide,
              autofillHint: AutofillHints.newPassword,
              onToggle: () => setState(() => _hide = !_hide),
              validator: (v) =>
                  (v ?? '').length < 6 ? 'استخدم ٦ أحرف أو أرقام على الأقل.' : null,
            ),
            const SizedBox(height: 14),
            _PasswordField(
              controller: _confirm,
              label: AppStrings.confirmPassword,
              obscure: _hide,
              autofillHint: AutofillHints.newPassword,
              onToggle: () => setState(() => _hide = !_hide),
              validator: (v) =>
                  v != _password.text ? 'كلمتا المرور غير متطابقتين.' : null,
            ),
            const SizedBox(height: 20),
            _GradientButton(
              label: 'حفظ كلمة المرور',
              icon: Icons.check_rounded,
              busy: false,
              onPressed: () {
                if (_form.currentState?.validate() ?? false) {
                  Navigator.pop(context, _password.text);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetShell extends StatelessWidget {
  const _SheetShell({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              height: 4,
              width: 44,
              decoration: BoxDecoration(
                color: AppColors.outline,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: title, subtitle: subtitle),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}
