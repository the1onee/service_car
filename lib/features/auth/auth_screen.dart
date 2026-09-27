import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:barrr/core/app_scope.dart';
import 'package:barrr/core/phone.dart';
import 'package:barrr/core/strings.dart';
import 'package:barrr/core/theme.dart';
import 'package:barrr/data/collections.dart';
import 'package:barrr/data/service_catalog.dart';
import 'package:barrr/features/shared/address_map_picker.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/models/vehicle_type.dart';
import 'package:barrr/services/auth_service.dart';
import 'package:barrr/services/specialties_catalog.dart';


part 'auth_widgets.part.dart';

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
  final _workshopOps = TextEditingController();
  final _otp = TextEditingController();
  GeoPoint? _registerGeo;

  _Stage _stage = _Stage.login;
  UserRole _registerRole = UserRole.customer;
  OilWorkshopTier _oilWorkshopTier = OilWorkshopTier.trusted;
  final Set<String> _skills = {};
  final Set<String> _vehicleTypes = {};
  String? _cityId;
  String? _specialtyId;
  List<({String id, String nameAr})> _cities = const [];
  List<SpecialtyOption> _specialties = const [];
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
      _workshopOps,
      _otp,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isWorkshopRole =>
      _registerRole == UserRole.workshop ||
      _registerRole == UserRole.oilWorkshop ||
      _registerRole == UserRole.paintShop;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadCitiesOnce();
  }

  var _citiesLoaded = false;
  Future<void> _loadCitiesOnce() async {
    if (_citiesLoaded) return;
    _citiesLoaded = true;
    try {
      final snap = await FirebaseFirestore.instance
          .collection(Cols.cities)
          .where('active', isEqualTo: true)
          .get();
      final list = snap.docs
          .map((d) {
            final data = d.data();
            return (
              id: d.id,
              nameAr: (data['nameAr'] as String?)?.trim().isNotEmpty == true
                  ? data['nameAr'] as String
                  : d.id,
            );
          })
          .toList()
        ..sort((a, b) => a.nameAr.compareTo(b.nameAr));
      if (!mounted) return;
      setState(() => _cities = list);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cities = const [
          (id: 'basra', nameAr: 'البصرة'),
          (id: 'baghdad', nameAr: 'بغداد'),
        ];
      });
    }
  }

  Future<void> _loadSpecialtiesForRole(UserRole role) async {
    if (role != UserRole.workshop &&
        role != UserRole.oilWorkshop &&
        role != UserRole.paintShop) {
      setState(() {
        _specialties = const [];
        _specialtyId = null;
      });
      return;
    }
    try {
      final list = await loadWorkshopSpecialties(role: role.name);
      if (!mounted) return;
      setState(() {
        _specialties = list;
        if (_specialtyId != null &&
            !list.any((s) => s.id == _specialtyId)) {
          _specialtyId = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _specialties = const [];
        _specialtyId = null;
      });
    }
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
          geo: _registerGeo,
          role: _registerRole,
          idCard: _idCard.text,
          serviceIds: switch (_registerRole) {
            UserRole.workshop => const ['parts'],
            UserRole.oilWorkshop => const ['oil'],
            UserRole.paintShop => const ['paint'],
            _ => _skills.toList(),
          },
          vehicleTypeIds: _registerRole == UserRole.oilWorkshop ||
                  _registerRole == UserRole.technician
              ? _vehicleTypes.toList()
              : const [],
          specialtyId: _specialtyId ?? '',
          specialtyAr: () {
            for (final s in _specialties) {
              if (s.id == _specialtyId) return s.nameAr;
            }
            return '';
          }(),
          workshopOps: _workshopOps.text,
          cityId: _cityId ?? '',
          cityNameAr: () {
            for (final c in _cities) {
              if (c.id == _cityId) return c.nameAr;
            }
            return '';
          }(),
          oilWorkshopTier: _registerRole == UserRole.oilWorkshop
              ? _oilWorkshopTier
              : null,
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

  Future<void> _pickRegisterAddress() async {
    final initial = _registerGeo != null
        ? LatLng(_registerGeo!.latitude, _registerGeo!.longitude)
        : null;
    final picked = await pickAddressOnMap(
      context,
      initial: initial,
      title: AppStrings.pickAddressOnMap,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _registerGeo = picked.geo;
      if (_address.text.trim().isEmpty) {
        _address.text = picked.label;
      }
    });
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
          onChanged: (role) {
            setState(() {
              _registerRole = role;
              _error = null;
              _specialtyId = null;
            });
            _loadSpecialtiesForRole(role);
          },
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
                decoration: InputDecoration(
                  labelText: _registerRole == UserRole.workshop ||
                          _registerRole == UserRole.oilWorkshop ||
                          _registerRole == UserRole.paintShop
                      ? AppStrings.workshopName
                      : AppStrings.name,
                  hintText: _registerRole == UserRole.oilWorkshop
                      ? 'مثال: وكالة تويوتا — خدمة زيوت متنقلة'
                      : (_registerRole == UserRole.paintShop
                          ? 'مثال: ورشة الألوان للدهان'
                          : (_registerRole == UserRole.workshop
                              ? 'مثال: ورشة النور لقطع الغيار'
                              : 'مثال: علي حسن الجابري')),
                  prefixIcon: Icon(
                    _registerRole == UserRole.workshop ||
                            _registerRole == UserRole.oilWorkshop ||
                            _registerRole == UserRole.paintShop
                        ? Icons.storefront_outlined
                        : Icons.person_outline_rounded,
                  ),
                ),
                validator: (v) {
                  final name = (v ?? '').trim();
                  if (name.length < 3) {
                    return _registerRole == UserRole.workshop ||
                            _registerRole == UserRole.oilWorkshop ||
                            _registerRole == UserRole.paintShop
                        ? 'أدخل اسم الورشة.'
                        : 'أدخل الاسم الكامل.';
                  }
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
              if (_registerRole == UserRole.technician ||
                  _registerRole == UserRole.workshop ||
                  _registerRole == UserRole.oilWorkshop ||
                  _registerRole == UserRole.paintShop) ...[
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
              if (_registerRole == UserRole.oilWorkshop) ...[
                const SizedBox(height: 14),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    AppStrings.oilWorkshopTier,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilterChip(
                        label: const Text(AppStrings.oilWorkshopAgency),
                        selected:
                            _oilWorkshopTier == OilWorkshopTier.agency,
                        onSelected: (_) => setState(
                          () => _oilWorkshopTier = OilWorkshopTier.agency,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilterChip(
                        label: const Text(AppStrings.oilWorkshopTrusted),
                        selected:
                            _oilWorkshopTier == OilWorkshopTier.trusted,
                        onSelected: (_) => setState(
                          () => _oilWorkshopTier = OilWorkshopTier.trusted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _workshopOps,
                  maxLines: 2,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: AppStrings.workshopOps,
                    hintText: 'مثال: تبديل زيت في الموقع، زيوت أصلية، فلاتر',
                    prefixIcon: Icon(Icons.handyman_outlined),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
              if (_isWorkshopRole) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _cityId,
                  decoration: const InputDecoration(
                    labelText: AppStrings.city,
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                  hint: const Text(AppStrings.selectCity),
                  items: _cities
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.nameAr),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _cityId = v),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'اختر المدينة.' : null,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _specialtyId,
                  decoration: const InputDecoration(
                    labelText: AppStrings.workshopSpecialty,
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  hint: const Text(AppStrings.selectSpecialty),
                  items: _specialties
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(s.nameAr),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _specialtyId = v),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'اختر اختصاص الورشة.' : null,
                ),
              ],
              if (_registerRole == UserRole.workshop ||
                  _registerRole == UserRole.paintShop) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _workshopOps,
                  maxLines: 2,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: AppStrings.workshopOps,
                    hintText: _registerRole == UserRole.paintShop
                        ? 'مثال: دهان صدام، تلميع، معالجة صدأ'
                        : 'مثال: توفير قطع أصلية، توصيل، فحص قبل البيع',
                    prefixIcon: const Icon(Icons.handyman_outlined),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              TextFormField(
                controller: _address,
                maxLines: 2,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.fullStreetAddress],
                decoration: InputDecoration(
                  labelText: AppStrings.address,
                  hintText: 'الحي، أقرب نقطة دالة — أو حدّد على الخريطة',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  alignLabelWithHint: true,
                  suffixIcon: IconButton(
                    tooltip: AppStrings.pickAddressOnMap,
                    onPressed: _pickRegisterAddress,
                    icon: const Icon(Icons.map_outlined),
                  ),
                ),
              ),
              if (_registerGeo != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      AppStrings.addressFromMap,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
                    for (final s in seedServices.where(
                      (s) => s.id != 'oil' && s.id != 'parts',
                    ))
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
                const SizedBox(height: 16),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    '${AppStrings.vehicleTypes} (${AppStrings.optional})',
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
                    for (final t in seedVehicleTypes)
                      FilterChip(
                        label: Text(t.nameAr),
                        selected: _vehicleTypes.contains(t.id),
                        onSelected: (on) => setState(() {
                          if (on) {
                            _vehicleTypes.add(t.id);
                          } else {
                            _vehicleTypes.remove(t.id);
                          }
                        }),
                      ),
                  ],
                ),
              ],
              if (_registerRole == UserRole.oilWorkshop) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    '${AppStrings.vehicleTypes} (${AppStrings.optional})',
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
                    for (final t in seedVehicleTypes)
                      FilterChip(
                        label: Text(t.nameAr),
                        selected: _vehicleTypes.contains(t.id),
                        onSelected: (on) => setState(() {
                          if (on) {
                            _vehicleTypes.add(t.id);
                          } else {
                            _vehicleTypes.remove(t.id);
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
