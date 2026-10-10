import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:barrr/core/app_brand.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/phone.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/services/auth_service.dart';

part 'auth_widgets.part.dart';

enum _Stage { login, register, resetSent }

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
  final _phone = TextEditingController();
  final _password = TextEditingController();

  _Stage _stage = _Stage.login;
  bool _hidePassword = true;
  bool _busy = false;
  String? _error;
  String? _resetEmail;

  @override
  void dispose() {
    for (final c in [
      _loginPhone,
      _loginPassword,
      _phone,
      _password,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

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
    _run(() => _auth.signInWithIdentifier(
          identifier: _loginPhone.text,
          password: _loginPassword.text,
        ));
  }

  void _continueWithGoogle() {
    _run(() async {
      final result = await _auth.signInWithGoogle();
      if (!mounted) return;
      if (result == GoogleAuthResult.cancelled) return;
    });
  }

  void _startRegistration() {
    if (!(_registerForm.currentState?.validate() ?? false)) return;
    _run(() => _auth.registerWithIdentifier(
          identifier: _phone.text,
          password: _password.text,
        ));
  }

  Future<void> _openForgotPassword() async {
    final identifier = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ForgotPasswordSheet(initialValue: _loginPhone.text),
    );
    if (identifier == null || !mounted) return;

    final trimmed = identifier.trim();
    if (isPhoneBackedIdentifier(trimmed)) {
      await _showPhoneResetBlocked();
      return;
    }

    if (!looksLikeEmail(trimmed) || isPhoneAuthEmail(trimmed)) {
      setState(() => _error = 'أدخل بريداً إلكترونياً صالحاً.');
      return;
    }

    _run(() async {
      await _auth.sendPasswordResetForEmail(trimmed);
      if (!mounted) return;
      setState(() {
        _stage = _Stage.resetSent;
        _resetEmail = trimmed.toLowerCase();
        _error = null;
      });
    });
  }

  Future<void> _showPhoneResetBlocked() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SheetShell(
        title: AppStrings.phoneResetBlockedTitle,
        subtitle: AppStrings.phoneResetBlockedBody,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.outline),
              ),
              child: Row(
                children: [
                  const Icon(Icons.support_agent_rounded, color: AppColors.petrol),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppStrings.supportPhone,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppColors.petrolDark,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _GradientButton(
              label: AppStrings.callSupport,
              icon: Icons.phone_rounded,
              busy: false,
              onPressed: () => _dialSupport(),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('حسناً'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _dialSupport() async {
    final uri = Uri(scheme: 'tel', path: AppStrings.supportPhone);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  String _friendlyError(Object e) {
    if (e is! FirebaseAuthException) return 'تعذر إكمال العملية. حاول مرة أخرى.';
    switch (e.code) {
      case 'invalid-phone-number':
        return 'رقم الهاتف غير صالح. استخدم صيغة 07701234567';
      case 'invalid-credential':
      case 'wrong-password':
        return 'رقم الهاتف أو كلمة المرور غير صحيحة.';
      case 'invalid-email':
        return e.message?.trim().isNotEmpty == true
            ? e.message!
            : 'البريد الإلكتروني غير صالح.';
      case 'user-not-found':
        // Firebase غالباً يخفي وجود الحساب؛ نعرض رسالة عامة.
        return AppStrings.resetEmailSentBody;
      case 'user-disabled':
        return 'هذا الحساب موقوف. راجع الإدارة.';
      case 'phone-already-registered':
        return 'هذا الحساب مسجّل مسبقاً. سجّل الدخول.';
      case 'too-many-requests':
        return 'محاولات كثيرة. انتظر قليلاً ثم أعد المحاولة.';
      case 'google-sign-in-failed':
        return e.message?.trim().isNotEmpty == true
            ? e.message!
            : 'تعذّر تسجيل الدخول عبر Google.';
      case 'operation-not-allowed':
        return 'مزوّد الدخول غير مفعّل في Firebase.';
      case 'network-request-failed':
        return e.message?.trim().isNotEmpty == true
            ? e.message!
            : 'لا يوجد اتصال بالإنترنت.';
      case 'weak-password':
        return 'كلمة المرور ضعيفة، استخدم ٦ أحرف على الأقل.';
      case 'internal-error':
        return e.message?.trim().isNotEmpty == true
            ? e.message!
            : 'تعذر إكمال العملية. حاول مرة أخرى.';
      default:
        final message = e.message?.trim() ?? '';
        if (message.length < 12) {
          return 'تعذر إكمال العملية (${e.code}). حاول مرة أخرى.';
        }
        return message;
    }
  }

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
            _Stage.resetSent => _resetSentView(),
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
        const SizedBox(height: 20),
        Center(
          child: _GoogleCircleButton(
            busy: _busy,
            onPressed: _continueWithGoogle,
          ),
        ),
        const SizedBox(height: 22),
        Form(
          key: _loginForm,
          child: Column(
            children: [
              _IdentifierField(
                controller: _loginPhone,
                onSubmitted: (_) => _login(),
              ),
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
        const SizedBox(height: 20),
        Center(
          child: _GoogleCircleButton(
            busy: _busy,
            onPressed: _continueWithGoogle,
          ),
        ),
        const SizedBox(height: 22),
        Form(
          key: _registerForm,
          child: Column(
            children: [
              _IdentifierField(controller: _phone),
              const SizedBox(height: 14),
              _PasswordField(
                controller: _password,
                label: AppStrings.password,
                obscure: _hidePassword,
                autofillHint: AutofillHints.newPassword,
                onToggle: () => setState(() => _hidePassword = !_hidePassword),
                validator: (v) {
                  if ((v ?? '').length < 6) {
                    return 'استخدم ٦ أحرف أو أرقام على الأقل.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        _errorBanner(),
        const SizedBox(height: 20),
        _GradientButton(
          label: AppStrings.register,
          icon: Icons.person_add_alt_1_rounded,
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

  Widget _resetSentView() {
    return Column(
      key: const ValueKey('resetSent'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Pill(
          icon: Icons.mark_email_read_rounded,
          label: 'رابط بالبريد',
          color: AppColors.azure,
          tint: AppColors.azureTint,
        ),
        const SizedBox(height: 16),
        const _SectionTitle(
          title: AppStrings.resetEmailSentTitle,
          subtitle: AppStrings.resetEmailSentBody,
        ),
        if (_resetEmail != null) ...[
          const SizedBox(height: 8),
          Text(
            _resetEmail!,
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.petrol,
            ),
          ),
        ],
        const SizedBox(height: 22),
        _GradientButton(
          label: AppStrings.login,
          icon: Icons.login_rounded,
          busy: false,
          onPressed: () => setState(() {
            _stage = _Stage.login;
            _resetEmail = null;
            _error = null;
          }),
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
                border:
                    Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
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
