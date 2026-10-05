import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:barrr/core/api_config.dart';
import 'package:barrr/core/phone.dart';
import 'package:barrr/data/collections.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/services/user_repository.dart';

/// سبب طلب رمز التحقق، يحدد ما يحدث بعد تأكيد الرمز.
enum OtpPurpose { register, resetPassword }

/// المصادقة تعتمد رقم الهاتف + كلمة المرور.
///
/// Firebase لا يدعم كلمة مرور لمزوّد الهاتف، لذلك يُربط كل رقم ببريد داخلي
/// ثابت ([phoneAuthEmail]) يحمل كلمة المرور، بينما يُستخدم رمز واتساب لإثبات
/// ملكية الرقم عند إنشاء الحساب أو استعادة كلمة المرور (عبر سيرفر VPS).
///
/// ترتيب إنشاء الحساب: يُنشأ الحساب أولاً بالبريد الداخلي وكلمة المرور،
/// ثم يُرسل رمز واتساب، وبعد التأكيد يُكتب ملف المستخدم في Firestore.
class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? db, http.Client? httpClient})
      : _authOr = auth,
        _dbOr = db,
        _http = httpClient ?? http.Client();

  final FirebaseAuth? _authOr;
  final FirebaseFirestore? _dbOr;
  final http.Client _http;

  FirebaseAuth get _auth => _authOr ?? FirebaseAuth.instance;
  FirebaseFirestore get _db => _dbOr ?? FirebaseFirestore.instance;

  /// الرقم بصيغة E.164 الذي أُرسل إليه آخر رمز تحقق.
  String? pendingPhone;

  /// صحيح أثناء إنشاء حساب لم يكتمل، ليبقى المستخدم على شاشة التحقق.
  final ValueNotifier<bool> registering = ValueNotifier(false);

  /// جلسة صالحة إذا رُبط الرقم، أو إذا وُجد ملف في Firestore
  /// (حسابات واتساب/لوحة التحكم بلا Phone Auth).
  Stream<String?> get uidChanges => _auth.userChanges().asyncMap((u) async {
        if (u == null) return null;
        if (u.phoneNumber != null) return u.uid;
        final doc = await _db.collection(Cols.users).doc(u.uid).get();
        return doc.exists ? u.uid : null;
      });

  String? get currentUid => _auth.currentUser?.uid;

  String? get currentPhone => _auth.currentUser?.phoneNumber ?? pendingPhone;

  /// تسجيل الدخول بالهاتف وكلمة المرور.
  Future<void> signIn({required String phone, required String password}) async {
    final e164 = _requireIraqiMobile(phone);
    await _auth.signInWithEmailAndPassword(
      email: phoneAuthEmail(e164),
      password: password,
    );
  }

  /// الخطوة الأولى: إنشاء الحساب بكلمة المرور ثم إرسال رمز واتساب.
  Future<void> startRegistration({
    required String phone,
    required String password,
  }) async {
    final e164 = _requireIraqiMobile(phone);
    pendingPhone = e164;
    registering.value = true;
    final email = phoneAuthEmail(e164);

    final leftover = _auth.currentUser;
    if (leftover != null && !await _hasProfile(leftover.uid)) {
      await _discardIncompleteAccount(leftover);
    }

    User? user;
    try {
      try {
        user = (await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        ))
            .user!;
      } on FirebaseAuthException catch (e) {
        if (e.code != 'email-already-in-use') rethrow;
        user = await _resumeIncompleteRegistration(email, password);
      }
      await _sendWhatsAppOtp(e164, OtpPurpose.register);
    } catch (_) {
      if (user != null) await _discardIncompleteAccount(user);
      registering.value = false;
      rethrow;
    }
  }

  /// تأكيد رمز واتساب وكتابة ملف المستخدم (بدون ربط Phone Auth).
  Future<void> completeRegistration({
    required String smsCode,
    required String name,
    String address = '',
    GeoPoint? geo,
    UserRole role = UserRole.customer,
    String idCard = '',
    List<String> serviceIds = const [],
    List<String> vehicleTypeIds = const [],
    String specialtyId = '',
    String specialtyAr = '',
    String workshopOps = '',
    String cityId = '',
    String cityNameAr = '',
    OilWorkshopTier? oilWorkshopTier,
  }) async {
    final e164 = pendingPhone;
    final user = _auth.currentUser;
    if (e164 == null || user == null) {
      throw FirebaseAuthException(
        code: 'session-expired',
        message: 'انتهت الجلسة، أعد طلب رمز التحقق.',
      );
    }
    if (role != UserRole.customer &&
        role != UserRole.technician &&
        role != UserRole.workshop &&
        role != UserRole.oilWorkshop &&
        role != UserRole.paintShop) {
      throw FirebaseAuthException(
        code: 'invalid-argument',
        message: 'نوع الحساب غير صالح.',
      );
    }
    final code = _requireCode(smsCode);
    final needsApproval = role == UserRole.technician ||
        role == UserRole.workshop ||
        role == UserRole.oilWorkshop ||
        role == UserRole.paintShop;
    final resolvedServices = switch (role) {
      UserRole.workshop =>
        serviceIds.isEmpty ? const ['parts'] : serviceIds,
      UserRole.oilWorkshop =>
        serviceIds.isEmpty ? const ['oil'] : serviceIds,
      UserRole.paintShop =>
        serviceIds.isEmpty ? const ['paint'] : serviceIds,
      _ => serviceIds,
    };

    try {
      await _verifyWhatsAppOtp(e164, code);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-verification-code' ||
          e.code == 'session-expired' ||
          e.code == 'too-many-requests') {
        rethrow;
      }
      await _discardIncompleteAccount(user);
      rethrow;
    }

    try {
      await user.updateDisplayName(name.trim());
      await _db.collection(Cols.users).doc(user.uid).set({
        ...AppUser(
          id: user.uid,
          role: role,
          name: name.trim(),
          phone: e164,
          address: address.trim(),
          idCard: idCard.trim(),
          serviceIds: resolvedServices,
          vehicleTypeIds: vehicleTypeIds,
          specialtyId: specialtyId.trim(),
          specialtyAr: specialtyAr.trim(),
          workshopOps: workshopOps.trim(),
          cityId: cityId.trim(),
          cityNameAr: cityNameAr.trim(),
          oilWorkshopTier: role == UserRole.oilWorkshop
              ? (oilWorkshopTier ?? OilWorkshopTier.trusted)
              : null,
          geo: geo,
          verified: !needsApproval,
          verificationStatus: needsApproval
              ? VerificationStatus.pending
              : VerificationStatus.approved,
        ).toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      await _discardIncompleteAccount(user);
      rethrow;
    }
    registering.value = false;
  }

  /// إرسال رمز واتساب لاستعادة كلمة المرور لرقم مسجّل مسبقاً.
  Future<void> sendResetOtp(String rawPhone) async {
    final e164 = _requireIraqiMobile(rawPhone);
    pendingPhone = e164;
    if (_auth.currentUser != null) await _auth.signOut();
    await _sendWhatsAppOtp(e164, OtpPurpose.resetPassword);
  }

  /// إعادة إرسال الرمز حسب سياق الطلب الحالي.
  Future<void> resendOtp(OtpPurpose purpose) async {
    final e164 = pendingPhone;
    if (e164 == null) {
      throw FirebaseAuthException(
        code: 'session-expired',
        message: 'أعد طلب رمز التحقق.',
      );
    }
    await _sendWhatsAppOtp(e164, purpose);
  }

  /// تعيين كلمة مرور جديدة بعد تأكيد الرقم برمز واتساب (على السيرفر).
  Future<void> resetPassword({
    required String smsCode,
    required String newPassword,
  }) async {
    final e164 = pendingPhone;
    if (e164 == null) {
      throw FirebaseAuthException(
        code: 'session-expired',
        message: 'أعد طلب رمز التحقق.',
      );
    }
    final code = _requireCode(smsCode);
    if (newPassword.length < 6) {
      throw FirebaseAuthException(
        code: 'weak-password',
        message: 'كلمة المرور ضعيفة، استخدم ٦ أحرف على الأقل.',
      );
    }

    await _apiPost(
      '/api/auth/reset-password',
      body: {
        'phone': e164,
        'code': code,
        'newPassword': newPassword,
      },
      auth: false,
    );
  }

  Future<void> signOut() async {
    pendingPhone = null;
    registering.value = false;
    await clearCachedProfile();
    await _auth.signOut();
  }

  /// إلغاء تسجيل لم يكتمل عند تراجع المستخدم عن شاشة التحقق.
  Future<void> cancelRegistration() async {
    final user = _auth.currentUser;
    if (user != null && !await _hasProfile(user.uid)) {
      await _discardIncompleteAccount(user);
    }
    registering.value = false;
  }

  Future<void> _sendWhatsAppOtp(String e164, OtpPurpose purpose) async {
    final needAuth = purpose == OtpPurpose.register;
    await _apiPost(
      '/api/auth/otp/send',
      body: {
        'phone': e164,
        'purpose':
            purpose == OtpPurpose.resetPassword ? 'resetPassword' : 'register',
      },
      auth: needAuth,
    );
  }

  Future<void> _verifyWhatsAppOtp(String e164, String code) async {
    await _apiPost(
      '/api/auth/otp/verify',
      body: {
        'phone': e164,
        'code': code,
      },
      auth: true,
    );
  }

  Future<Map<String, dynamic>> _apiPost(
    String path, {
    required Map<String, dynamic> body,
    required bool auth,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (auth) {
      final user = _auth.currentUser;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'session-expired',
          message: 'انتهت الجلسة، أعد طلب رمز التحقق.',
        );
      }
      final idToken = await user.getIdToken();
      headers['Authorization'] = 'Bearer $idToken';
    }

    late http.Response res;
    try {
      res = await _http
          .post(
            ApiConfig.uri(path),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw FirebaseAuthException(
        code: 'network-request-failed',
        message: 'انتهت مهلة الاتصال بسيرفر التحقق.',
      );
    } catch (e) {
      debugPrint('auth api error: $e');
      throw FirebaseAuthException(
        code: 'network-request-failed',
        message:
            'تعذّر الاتصال بسيرفر التحقق. تأكد أن السيرفر يعمل على ${ApiConfig.baseUrl}',
      );
    }

    Map<String, dynamic> data = {};
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {}

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return data;
    }

    final code = (data['error'] as String?)?.trim();
    final message = (data['message'] as String?)?.trim();
    throw FirebaseAuthException(
      code: _mapApiErrorCode(code, res.statusCode),
      message: (message != null && message.isNotEmpty)
          ? message
          : 'تعذّر إكمال التحقق (${res.statusCode}).',
    );
  }

  String _mapApiErrorCode(String? code, int status) {
    switch (code) {
      case 'invalid-verification-code':
      case 'session-expired':
      case 'too-many-requests':
      case 'quota-exceeded':
      case 'user-not-found':
      case 'invalid-phone-number':
      case 'phone-already-registered':
      case 'weak-password':
      case 'whatsapp_not_configured':
        return code!;
      default:
        if (status == 429) return 'too-many-requests';
        if (status == 404) return 'user-not-found';
        if (status == 401 || status == 403) return 'session-expired';
        return code?.isNotEmpty == true ? code! : 'internal-error';
    }
  }

  Future<bool> _hasProfile(String uid) async {
    final doc = await _db.collection(Cols.users).doc(uid).get();
    return doc.exists;
  }

  /// حساب موجود بنفس البريد الداخلي: نتابعه إن كان تسجيلاً ناقصاً بلا ملف.
  Future<User> _resumeIncompleteRegistration(
    String email,
    String password,
  ) async {
    final alreadyRegistered = FirebaseAuthException(
      code: 'phone-already-registered',
      message: 'هذا الرقم مسجّل مسبقاً. سجّل الدخول بكلمة المرور.',
    );

    final User user;
    try {
      user = (await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      ))
          .user!;
    } on FirebaseAuthException {
      throw alreadyRegistered;
    }

    if (user.phoneNumber != null || await _hasProfile(user.uid)) {
      await _auth.signOut();
      throw alreadyRegistered;
    }
    return user;
  }

  String _requireCode(String smsCode) {
    final code = smsCode.trim();
    if (code.length < 6) {
      throw FirebaseAuthException(
        code: 'invalid-verification-code',
        message: 'رمز التحقق غير مكتمل.',
      );
    }
    return code;
  }

  String _requireIraqiMobile(String rawPhone) {
    final e164 = normalizeIraqiPhone(rawPhone);
    if (!looksLikeIraqiMobile(e164)) {
      throw FirebaseAuthException(
        code: 'invalid-phone-number',
        message: 'رقم الهاتف غير صالح. مثال: 07701234567',
      );
    }
    return e164;
  }

  Future<void> _discardIncompleteAccount(User user) async {
    try {
      await user.delete();
    } catch (_) {
      await _auth.signOut();
    }
  }
}
