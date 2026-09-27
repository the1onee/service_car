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
    return Column(
      children: [
        Row(
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
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _roleTile(
                label: AppStrings.workshop,
                selected: role == UserRole.workshop,
                onTap: () => onChanged(UserRole.workshop),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _roleTile(
                label: AppStrings.oilWorkshop,
                selected: role == UserRole.oilWorkshop,
                onTap: () => onChanged(UserRole.oilWorkshop),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _roleTile(
                label: AppStrings.paintShop,
                selected: role == UserRole.paintShop,
                onTap: () => onChanged(UserRole.paintShop),
              ),
            ),
            const Expanded(child: SizedBox()),
          ],
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
    final isWorkshop = role == UserRole.workshop;
    final isOilWorkshop = role == UserRole.oilWorkshop;
    final isPaintShop = role == UserRole.paintShop;
    final tint = isOilWorkshop || isPaintShop
        ? AppColors.amberTint
        : (isWorkshop
            ? AppColors.recessed
            : (isTech ? AppColors.amberTint : AppColors.petrolTint));
    final badge = isOilWorkshop || isPaintShop
        ? AppColors.amber
        : (isWorkshop
            ? AppColors.slate
            : (isTech ? AppColors.amber : AppColors.petrol));
    final note = isPaintShop
        ? AppStrings.paintShopAccountNote
        : (isOilWorkshop
            ? AppStrings.oilWorkshopAccountNote
            : (isWorkshop
                ? AppStrings.workshopAccountNote
                : (isTech
                    ? AppStrings.technicianAccountNote
                    : AppStrings.customerAccountNote)));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: badge,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPaintShop
                  ? Icons.format_paint_rounded
                  : (isOilWorkshop
                      ? Icons.oil_barrel_rounded
                      : (isWorkshop
                          ? Icons.storefront_rounded
                          : (isTech
                              ? Icons.handyman_rounded
                              : Icons.person_rounded))),
              color: isTech || isOilWorkshop || isPaintShop
                  ? AppColors.ink
                  : Colors.white,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              note,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: isTech || isOilWorkshop || isPaintShop
                    ? AppColors.ink
                    : AppColors.petrolDark,
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
