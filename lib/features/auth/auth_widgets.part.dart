part of 'auth_screen.dart';

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
            colors: [AppColors.slate, AppColors.slateMid, AppColors.canvas],
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: Image.asset(
                  AppBrand.logoAsset,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.rv_hookup_rounded,
                    color: AppColors.ink,
                    size: 28,
                  ),
                ),
              ),
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

class _GoogleCircleButton extends StatelessWidget {
  const _GoogleCircleButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(
            side: BorderSide(color: Color(0xFFD0D7E2)),
          ),
          elevation: 2,
          shadowColor: Colors.black26,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: busy ? null : onPressed,
            child: SizedBox(
              width: 72,
              height: 72,
              child: Center(
                child: busy
                    ? const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : const Text(
                        'G',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF4285F4),
                          height: 1,
                        ),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          AppStrings.continueWithGoogle,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.inkSoft,
          ),
        ),
      ],
    );
  }
}

class _IdentifierField extends StatelessWidget {
  const _IdentifierField({
    required this.controller,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      textInputAction: TextInputAction.next,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.username, AutofillHints.email],
      textDirection: TextDirection.ltr,
      decoration: const InputDecoration(
        labelText: AppStrings.phoneOrEmail,
        hintText: AppStrings.phoneOrEmailHint,
        prefixIcon: Icon(Icons.person_outline_rounded),
      ),
      validator: (v) {
        final raw = (v ?? '').trim();
        if (raw.isEmpty) return 'أدخل رقم الهاتف أو البريد.';
        try {
          resolveAuthEmail(raw);
        } on FormatException catch (e) {
          return e.message;
        }
        return null;
      },
      onFieldSubmitted: onSubmitted,
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

/// طلب المعرّف لبدء استعادة كلمة المرور (إيميل أو هاتف).
class _ForgotPasswordSheet extends StatefulWidget {
  const _ForgotPasswordSheet({required this.initialValue});

  final String initialValue;

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  final _form = GlobalKey<FormState>();
  late final _identifier = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _identifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: AppStrings.resetPassword,
      subtitle: AppStrings.resetPasswordEmailHint,
      child: Form(
        key: _form,
        child: Column(
          children: [
            _IdentifierField(controller: _identifier),
            const SizedBox(height: 20),
            _GradientButton(
              label: AppStrings.sendResetLink,
              icon: Icons.mail_outline_rounded,
              busy: false,
              onPressed: () {
                if (_form.currentState?.validate() ?? false) {
                  Navigator.pop(context, _identifier.text);
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
