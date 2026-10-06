import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:barrr/core/api_config.dart';
import 'package:barrr/core/phone.dart';
import 'package:barrr/data/collections.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/services/user_repository.dart';

/// نتيجة تسجيل الدخول عبر Google.
enum GoogleAuthResult {
  /// يوجد ملف أو اكتمل إنشاؤه — يدخل التطبيق.
  signedIn,

  /// أغلق نافذة Google دون إكمال.
  cancelled,
}

/// المصادقة: Google أو هاتف/بريد + كلمة المرور.
/// استعادة كلمة المرور عبر رمز واتساب على السيرفر.
class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? db,
    http.Client? httpClient,
    Stream<String?>? uidChangesOverride,
    String? Function()? currentUidOverride,
  })  : _authOr = auth,
        _dbOr = db,
        _http = httpClient ?? http.Client(),
        _uidChangesOverride = uidChangesOverride,
        _currentUidOverride = currentUidOverride;

  final FirebaseAuth? _authOr;
  final FirebaseFirestore? _dbOr;
  final http.Client _http;
  final Stream<String?>? _uidChangesOverride;
  final String? Function()? _currentUidOverride;

  FirebaseAuth get _auth => _authOr ?? FirebaseAuth.instance;
  FirebaseFirestore get _db => _dbOr ?? FirebaseFirestore.instance;

  bool _googleInitialized = false;

  /// الرقم الذي أُرسل إليه آخر رمز استعادة.
  String? pendingPhone;

  /// صحيح أثناء إنشاء حساب لم يكتمل ملفه بعد.
  final ValueNotifier<bool> registering = ValueNotifier(false);

  Stream<String?> get uidChanges =>
      _uidChangesOverride ??
      _auth.userChanges().asyncMap((u) async {
        if (u == null) return null;
        if (u.phoneNumber != null) return u.uid;
        final doc = await _db.collection(Cols.users).doc(u.uid).get();
        return doc.exists ? u.uid : null;
      });

  String? get currentUid =>
      _currentUidOverride != null ? _currentUidOverride!() : _auth.currentUser?.uid;

  String? get currentPhone => _auth.currentUser?.phoneNumber ?? pendingPhone;

  Future<void> _ensureGoogleInitialized() async {
    if (kIsWeb || _googleInitialized) return;
    await GoogleSignIn.instance.initialize();
    _googleInitialized = true;
  }

  Future<GoogleAuthResult> signInWithGoogle() async {
    try {
      final UserCredential cred;
      if (kIsWeb) {
        cred = await _auth.signInWithPopup(GoogleAuthProvider());
      } else {
        await _ensureGoogleInitialized();
        final googleUser = await GoogleSignIn.instance.authenticate();
        final idToken = googleUser.authentication.idToken;
        if (idToken == null || idToken.isEmpty) {
          throw FirebaseAuthException(
            code: 'invalid-credential',
            message: 'تعذّر الحصول على رمز Google. أعد المحاولة.',
          );
        }
        cred = await _auth.signInWithCredential(
          GoogleAuthProvider.credential(idToken: idToken),
        );
      }

      final user = cred.user;
      if (user == null) return GoogleAuthResult.cancelled;

      if (await _hasProfile(user.uid)) {
        registering.value = false;
        return GoogleAuthResult.signedIn;
      }

      final name = (user.displayName?.trim().isNotEmpty == true)
          ? user.displayName!.trim()
          : (user.email?.split('@').first ?? 'مستخدم');
      await _writeCustomerProfile(
        user: user,
        phone: '',
        name: name,
        authProvider: 'google',
        photoUrl: user.photoURL ?? '',
        email: user.email ?? '',
        discardOnFailure: false,
      );
      registering.value = false;
      return GoogleAuthResult.signedIn;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return GoogleAuthResult.cancelled;
      }
      throw FirebaseAuthException(
        code: 'google-sign-in-failed',
        message: e.description ?? 'تعذّر تسجيل الدخول عبر Google.',
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        return GoogleAuthResult.cancelled;
      }
      rethrow;
    }
  }

  Future<void> signInWithIdentifier({
    required String identifier,
    required String password,
  }) async {
    final String email;
    try {
      email = resolveAuthEmail(identifier);
    } on FormatException catch (e) {
      throw FirebaseAuthException(code: 'invalid-email', message: e.message);
    }
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> registerWithIdentifier({
    required String identifier,
    required String password,
  }) async {
    if (password.length < 6) {
      throw FirebaseAuthException(
        code: 'weak-password',
        message: 'كلمة المرور ضعيفة، استخدم ٦ أحرف على الأقل.',
      );
    }

    final String email;
    String phone = '';
    try {
      email = resolveAuthEmail(identifier);
      phone = phoneFromIdentifier(identifier);
    } on FormatException catch (e) {
      throw FirebaseAuthException(code: 'invalid-email', message: e.message);
    }

    pendingPhone = phone.isEmpty ? null : phone;
    registering.value = true;

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
        throw FirebaseAuthException(
          code: 'phone-already-registered',
          message: 'هذا الحساب مسجّل مسبقاً. سجّل الدخول.',
        );
      }

      final name =
          phone.isNotEmpty ? prettyIraqiPhone(phone) : email.split('@').first;
      await _writeCustomerProfile(
        user: user,
        phone: phone,
        name: name,
        authProvider: phone.isNotEmpty ? 'phone' : 'email',
        email: email.contains('@phone.barrr.app') ? '' : email,
        discardOnFailure: true,
      );
      registering.value = false;
    } catch (_) {
      if (user != null) await _discardIncompleteAccount(user);
      registering.value = false;
      rethrow;
    }
  }

  Future<void> _writeCustomerProfile({
    required User user,
    required String phone,
    required String name,
    required String authProvider,
    String photoUrl = '',
    String email = '',
    required bool discardOnFailure,
  }) async {
    try {
      final trimmedName = name.trim();
      if (trimmedName.isNotEmpty && user.displayName != trimmedName) {
        await user.updateDisplayName(trimmedName);
      }
      await _db.collection(Cols.users).doc(user.uid).set({
        ...AppUser(
          id: user.uid,
          role: UserRole.customer,
          name: trimmedName,
          phone: phone,
          photoUrl: photoUrl,
          verified: true,
          verificationStatus: VerificationStatus.approved,
        ).toMap(),
        'email': email,
        'authProvider': authProvider,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (discardOnFailure) await _discardIncompleteAccount(user);
      rethrow;
    }
  }

  Future<void> sendResetOtp(String rawPhone) async {
    final e164 = _requireIraqiMobile(rawPhone);
    pendingPhone = e164;
    if (_auth.currentUser != null) await _auth.signOut();
    await _sendWhatsAppResetOtp(e164);
  }

  Future<void> resendOtp() async {
    final e164 = pendingPhone;
    if (e164 == null) {
      throw FirebaseAuthException(
        code: 'session-expired',
        message: 'أعد طلب رمز التحقق.',
      );
    }
    await _sendWhatsAppResetOtp(e164);
  }

  Future<void> resetPassword({
    required String smsCode,
    required String newPassword,
  }) async {
    final e164 = pendingPhone;
    if (e164 == null) {
      throw FirebaseAuthException(
        code: 'session-expired',
        message: 'انتهت الجلسة، أعد طلب رمز التحقق.',
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
    if (!kIsWeb && _googleInitialized) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
    await _auth.signOut();
  }

  Future<void> cancelRegistration() async {
    final user = _auth.currentUser;
    registering.value = false;
    pendingPhone = null;
    if (user == null) return;
    if (await _hasProfile(user.uid)) return;
    final isGoogle = user.providerData.any((p) => p.providerId == 'google.com');
    if (isGoogle) {
      await signOut();
      return;
    }
    await _discardIncompleteAccount(user);
  }

  Future<void> _sendWhatsAppResetOtp(String e164) async {
    debugPrint(
      'auth otp send → ${ApiConfig.baseUrl}/api/auth/otp/send phone=$e164 purpose=resetPassword',
    );
    await _apiPost(
      '/api/auth/otp/send',
      body: {
        'phone': e164,
        'purpose': 'resetPassword',
      },
      auth: false,
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
      case 'whatsapp_template_missing':
      case 'whatsapp_send_failed':
      case 'google-sign-in-failed':
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
