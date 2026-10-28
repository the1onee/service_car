import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:barrr/core/api_config.dart';
import 'package:barrr/core/phone.dart';
import 'package:barrr/data/collections.dart';
import 'package:barrr/models/app_user.dart';
import 'package:barrr/services/user_repository.dart';

/// نتيجة تسجيل الدخول عبر Google أو Apple.
enum GoogleAuthResult {
  /// يوجد ملف أو اكتمل إنشاؤه — يدخل التطبيق.
  signedIn,

  /// أغلق نافذة المزوّد دون إكمال.
  cancelled,
}

/// المصادقة: Google أو هاتف/بريد + كلمة المرور.
/// استعادة كلمة المرور عبر رابط Firebase للإيميل الحقيقي فقط.
class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? db,
    Stream<String?>? uidChangesOverride,
    String? Function()? currentUidOverride,
  })  : _authOr = auth,
        _dbOr = db,
        _uidChangesOverride = uidChangesOverride,
        _currentUidOverride = currentUidOverride;

  final FirebaseAuth? _authOr;
  final FirebaseFirestore? _dbOr;
  final Stream<String?>? _uidChangesOverride;
  final String? Function()? _currentUidOverride;

  FirebaseAuth get _auth => _authOr ?? FirebaseAuth.instance;
  FirebaseFirestore get _db => _dbOr ?? FirebaseFirestore.instance;

  bool _googleInitialized = false;

  /// عميل الويب (client_type 3) من Firebase. أندرويد يحتاجه لإصدار رمز Google.
  static const _googleServerClientId =
      '500429219707-grrldfcsp3cf6j9u01rrnndbecj8jelr.apps.googleusercontent.com';

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

  String? get currentUid {
    final override = _currentUidOverride;
    if (override != null) return override();
    return _auth.currentUser?.uid;
  }

  String? get currentPhone => _auth.currentUser?.phoneNumber ?? pendingPhone;

  Future<void> _ensureGoogleInitialized() async {
    if (kIsWeb || _googleInitialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: _googleServerClientId,
    );
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
      await _awaitSignedIn(user);

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

  /// Sign in with Apple — iOS فقط (مطلوب مع Google وفق Guideline 4.8).
  Future<GoogleAuthResult> signInWithApple() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      throw FirebaseAuthException(
        code: 'operation-not-allowed',
        message: 'تسجيل الدخول عبر Apple متاح على الآيفون فقط.',
      );
    }
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );
      final idToken = appleCredential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw FirebaseAuthException(
          code: 'apple-sign-in-failed',
          message: 'تعذّر الحصول على رمز Apple. أعد المحاولة.',
        );
      }
      // firebase_auth ≥5.2 يتطلب authorizationCode كـ accessToken وإلا
      // يفشل بـ invalid-credential ويُترجم خطأً لرسالة الهاتف/كلمة المرور.
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: idToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );
      final cred = await _auth.signInWithCredential(oauthCredential);
      final user = cred.user;
      if (user == null) return GoogleAuthResult.cancelled;
      await _awaitSignedIn(user);

      if (await _hasProfile(user.uid)) {
        registering.value = false;
        return GoogleAuthResult.signedIn;
      }

      final given = appleCredential.givenName?.trim() ?? '';
      final family = appleCredential.familyName?.trim() ?? '';
      final appleName = '$given $family'.trim();
      final name = appleName.isNotEmpty
          ? appleName
          : ((user.displayName?.trim().isNotEmpty == true)
              ? user.displayName!.trim()
              : (user.email?.split('@').first ?? 'مستخدم'));
      if (appleName.isNotEmpty && user.displayName != appleName) {
        await user.updateDisplayName(appleName);
      }
      await _writeCustomerProfile(
        user: user,
        phone: '',
        name: name,
        authProvider: 'apple',
        photoUrl: user.photoURL ?? '',
        email: user.email ?? '',
        discardOnFailure: false,
      );
      registering.value = false;
      return GoogleAuthResult.signedIn;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return GoogleAuthResult.cancelled;
      }
      throw FirebaseAuthException(
        code: 'apple-sign-in-failed',
        message: e.message.isNotEmpty
            ? e.message
            : 'تعذّر تسجيل الدخول عبر Apple.',
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-credential' ||
          e.code == 'invalid-oauth-response' ||
          e.code == 'missing-or-invalid-nonce') {
        throw FirebaseAuthException(
          code: 'apple-sign-in-failed',
          message: 'تعذّر التحقق من حساب Apple. أعد المحاولة.',
        );
      }
      if (e.code == 'operation-not-allowed') {
        throw FirebaseAuthException(
          code: 'apple-sign-in-failed',
          message: kReleaseMode
              ? 'تسجيل الدخول عبر Apple غير متاح حالياً.'
              : 'فعّل مزوّد Apple في Firebase Authentication.',
        );
      }
      rethrow;
    }
  }

  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
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

      await _awaitSignedIn(user);

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
      if (phone.isNotEmpty && looksLikeIraqiMobile(phone)) {
        final phoneKey = phone.replaceAll('+', '');
        final regRef = _db.collection(Cols.phoneRegistry).doc(phoneKey);
        await _db.runTransaction((tx) async {
          final regSnap = await tx.get(regRef);
          final owner = (regSnap.data()?['uid'] as String?)?.trim() ?? '';
          if (regSnap.exists && owner.isNotEmpty && owner != user.uid) {
            throw FirebaseAuthException(
              code: 'phone-already-registered',
              message: 'هذا الحساب مسجّل مسبقاً. سجّل الدخول.',
            );
          }
          tx.set(regRef, {
            'uid': user.uid,
            'phone': phone,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });
      }
    } catch (e) {
      if (discardOnFailure) await _discardIncompleteAccount(user);
      rethrow;
    }
  }

  /// يرسل رابط استعادة كلمة المرور عبر Firebase للإيميل الحقيقي فقط.
  Future<void> sendPasswordResetForEmail(String rawEmail) async {
    final email = rawEmail.trim().toLowerCase();
    if (!looksLikeEmail(email) || isPhoneAuthEmail(email)) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'أدخل بريداً إلكترونياً صالحاً لاستعادة كلمة المرور.',
      );
    }
    if (_auth.currentUser != null) await _auth.signOut();
    await _auth.sendPasswordResetEmail(email: email);
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

  /// حذف حساب العميل نهائياً عبر السيرفر (Auth + الملف + رقم الهاتف).
  Future<void> deleteOwnAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final token = await user.getIdToken(true);
    final res = await http
        .post(
          ApiConfig.uri('/api/users/delete-self'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      String message = 'تعذّر حذف الحساب. حاول لاحقاً أو تواصل مع الدعم.';
      try {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final m = (body['message'] as String?)?.trim() ?? '';
        if (m.isNotEmpty && res.statusCode < 500) message = m;
      } catch (_) {}
      throw FormatException(message);
    }
    await signOut();
  }

  Future<void> cancelRegistration() async {
    final user = _auth.currentUser;
    registering.value = false;
    pendingPhone = null;
    if (user == null) return;
    if (await _hasProfile(user.uid)) return;
    final isSocial = user.providerData.any(
      (p) => p.providerId == 'google.com' || p.providerId == 'apple.com',
    );
    if (isSocial) {
      await signOut();
      return;
    }
    await _discardIncompleteAccount(user);
  }

  /// ينتظر رمز الدخول قبل أي قراءة أو كتابة في Firestore.
  /// على أندرويد تُرفض أول عملية بـ permission-denied إن سبقت إرفاق الرمز.
  Future<void> _awaitSignedIn(User user) async {
    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw FirebaseAuthException(
        code: 'network-request-failed',
        message: 'تعذّر تأكيد الجلسة. أعد المحاولة.',
      );
    }
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  Future<bool> _hasProfile(String uid) async {
    final doc = await _db.collection(Cols.users).doc(uid).get();
    return doc.exists;
  }

  Future<void> _discardIncompleteAccount(User user) async {
    try {
      final snap = await _db.collection(Cols.users).doc(user.uid).get();
      final phone = (snap.data()?['phone'] as String?)?.trim() ?? '';
      if (snap.exists) {
        await _db.collection(Cols.users).doc(user.uid).delete();
      }
      if (phone.isNotEmpty && looksLikeIraqiMobile(phone)) {
        final regRef =
            _db.collection(Cols.phoneRegistry).doc(phone.replaceAll('+', ''));
        final reg = await regRef.get();
        if (reg.exists && (reg.data()?['uid'] as String?) == user.uid) {
          await regRef.delete();
        }
      }
    } catch (_) {}
    try {
      await user.delete();
    } catch (_) {
      await _auth.signOut();
    }
  }
}
