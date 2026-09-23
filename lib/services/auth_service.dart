import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:barrr/core/phone.dart';
import 'package:barrr/data/collections.dart';
import 'package:barrr/models/app_user.dart';

/// سبب طلب رمز التحقق، يحدد ما يحدث بعد تأكيد الرمز.
enum OtpPurpose { register, resetPassword }

/// المصادقة تعتمد رقم الهاتف + كلمة المرور.
///
/// Firebase لا يدعم كلمة مرور لمزوّد الهاتف، لذلك يُربط كل رقم ببريد داخلي
/// ثابت ([phoneAuthEmail]) يحمل كلمة المرور، بينما يُستخدم رمز SMS لإثبات
/// ملكية الرقم عند إنشاء الحساب أو استعادة كلمة المرور.
///
/// ترتيب إنشاء الحساب مقصود: يُنشأ الحساب أولاً بالبريد الداخلي وكلمة المرور،
/// ثم يُربط الهاتف بعد تأكيد الرمز. العكس مستحيل لأن حماية تعداد البُرَيد في
/// Firebase ترفض إضافة بريد إلى حساب هاتف قائم قبل التحقق من البريد، والبريد
/// الداخلي لا يستقبل رسائل فلا يمكن التحقق منه أبداً.
class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? db})
      : _authOr = auth,
        _dbOr = db;

  final FirebaseAuth? _authOr;
  final FirebaseFirestore? _dbOr;

  FirebaseAuth get _auth => _authOr ?? FirebaseAuth.instance;
  FirebaseFirestore get _db => _dbOr ?? FirebaseFirestore.instance;

  String? _verificationId;
  int? _resendToken;
  ConfirmationResult? _webConfirmation;

  /// الرقم بصيغة E.164 الذي أُرسل إليه آخر رمز تحقق.
  String? pendingPhone;

  /// صحيح أثناء إنشاء حساب لم يكتمل، ليبقى المستخدم على شاشة التحقق.
  final ValueNotifier<bool> registering = ValueNotifier(false);

  /// جلسة صالحة إذا رُبط الرقم، أو إذا وُجد ملف في Firestore
  /// (حسابات تُنشئها لوحة التحكم بالبريد الداخلي دون Phone Auth).
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

  /// الخطوة الأولى لإنشاء الحساب: يُنشأ الحساب بكلمة المرور ثم يُرسل رمز تحقق
  /// لربط الرقم به. يُستأنف تسجيل ناقص سابقاً بنفس كلمة المرور إن وُجد.
  Future<void> startRegistration({
    required String phone,
    required String password,
  }) async {
    final e164 = _requireIraqiMobile(phone);
    pendingPhone = e164;
    registering.value = true;
    final email = phoneAuthEmail(e164);

    // بقايا محاولة سابقة لم تكتمل على هذا الجهاز.
    final leftover = _auth.currentUser;
    if (leftover != null && leftover.phoneNumber == null) {
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
      await _sendPhoneOtp(e164, linkToCurrentUser: true);
    } catch (_) {
      if (user != null) await _discardIncompleteAccount(user);
      registering.value = false;
      rethrow;
    }
  }

  /// الخطوة الثانية: تأكيد الرمز، ربط الرقم بالحساب، وكتابة ملف المستخدم.
  Future<void> completeRegistration({
    required String smsCode,
    required String name,
    String address = '',
    GeoPoint? geo,
    UserRole role = UserRole.customer,
    String idCard = '',
    List<String> serviceIds = const [],
    List<String> vehicleTypeIds = const [],
  }) async {
    final e164 = pendingPhone;
    final user = _auth.currentUser;
    if (e164 == null || user == null) {
      throw FirebaseAuthException(
        code: 'session-expired',
        message: 'انتهت الجلسة، أعد طلب رمز التحقق.',
      );
    }
    if (role != UserRole.customer && role != UserRole.technician) {
      throw FirebaseAuthException(
        code: 'invalid-argument',
        message: 'نوع الحساب غير صالح.',
      );
    }
    final code = _requireCode(smsCode);
    final isTech = role == UserRole.technician;

    try {
      if (kIsWeb) {
        await _requireWebConfirmation().confirm(code);
      } else {
        await user.linkWithCredential(
          PhoneAuthProvider.credential(
            verificationId: _requireVerificationId(),
            smsCode: code,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      // رمز خاطئ ليس سبباً لحذف الحساب، المستخدم قد يعيد المحاولة.
      if (e.code == 'invalid-verification-code' ||
          e.code == 'invalid-verification-id') {
        rethrow;
      }
      await _discardIncompleteAccount(user);
      throw _mapLinkError(e);
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
          serviceIds: serviceIds,
          vehicleTypeIds: vehicleTypeIds,
          geo: geo,
          verified: !isTech,
          verificationStatus:
              isTech ? VerificationStatus.pending : VerificationStatus.approved,
        ).toMap(),
        // تحتاجه لوحة التحكم لترتيب الحسابات بتاريخ التسجيل.
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // لا نترك حساباً بلا ملف تعريف.
      await _discardIncompleteAccount(user);
      throw _mapLinkError(e);
    }
    registering.value = false;
  }

  /// إرسال رمز تحقق لاستعادة كلمة المرور لرقم مسجّل مسبقاً.
  Future<void> sendResetOtp(String rawPhone) async {
    final e164 = _requireIraqiMobile(rawPhone);
    pendingPhone = e164;
    if (_auth.currentUser != null) await _auth.signOut();
    await _sendPhoneOtp(e164, linkToCurrentUser: false);
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
    await _sendPhoneOtp(
      e164,
      linkToCurrentUser: purpose == OtpPurpose.register,
    );
  }

  /// تعيين كلمة مرور جديدة بعد تأكيد الرقم برمز SMS.
  Future<void> resetPassword({
    required String smsCode,
    required String newPassword,
  }) async {
    final code = _requireCode(smsCode);
    final credential = kIsWeb
        ? await _requireWebConfirmation().confirm(code)
        : await _auth.signInWithCredential(
            PhoneAuthProvider.credential(
              verificationId: _requireVerificationId(),
              smsCode: code,
            ),
          );

    final user = credential.user!;
    final isNew = credential.additionalUserInfo?.isNewUser ?? false;
    if (isNew) {
      // الاستعادة لا تُنشئ حسابات، نحذف ما أنشأه تسجيل الدخول بالهاتف.
      await _discardIncompleteAccount(user);
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'لا يوجد حساب بهذا الرقم. أنشئ حساباً جديداً.',
      );
    }
    if (!user.providerData.any((p) => p.providerId == 'password')) {
      await _auth.signOut();
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'لا يوجد حساب بهذا الرقم. أنشئ حساباً جديداً.',
      );
    }
    await user.updatePassword(newPassword);
  }

  Future<void> signOut() {
    _verificationId = null;
    _resendToken = null;
    _webConfirmation = null;
    pendingPhone = null;
    registering.value = false;
    return _auth.signOut();
  }

  /// إلغاء تسجيل لم يكتمل عند تراجع المستخدم عن شاشة التحقق.
  Future<void> cancelRegistration() async {
    final user = _auth.currentUser;
    if (user != null && user.phoneNumber == null) {
      await _discardIncompleteAccount(user);
    }
    _webConfirmation = null;
    _verificationId = null;
    registering.value = false;
  }

  /// إرسال الرمز: ربطاً بالحساب الحالي عند التسجيل، أو تسجيل دخول عند الاستعادة.
  Future<void> _sendPhoneOtp(
    String e164, {
    required bool linkToCurrentUser,
  }) async {
    if (kIsWeb) {
      // على الويب يُستخدم reCAPTCHA غير مرئي.
      _webConfirmation = linkToCurrentUser
          ? await _auth.currentUser!.linkWithPhoneNumber(e164)
          : await _auth.signInWithPhoneNumber(e164);
      return;
    }

    // منع مسار reCAPTCHA على أندرويد والاعتماد على Play Integrity.
    try {
      await _auth.setSettings(forceRecaptchaFlow: false);
    } catch (e) {
      debugPrint('setSettings: $e');
    }

    final completer = Completer<void>();
    await _auth.verifyPhoneNumber(
      phoneNumber: e164,
      timeout: const Duration(seconds: 60),
      forceResendingToken: _resendToken,
      verificationCompleted: (_) {},
      verificationFailed: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      codeSent: (verificationId, resendToken) {
        _verificationId = verificationId;
        _resendToken = resendToken;
        if (!completer.isCompleted) completer.complete();
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
      },
    );
    await completer.future;
  }

  /// حساب موجود بنفس البريد الداخلي: نتابعه إن كان تسجيلاً ناقصاً بلا رقم مربوط.
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

    if (user.phoneNumber != null) {
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

  ConfirmationResult _requireWebConfirmation() {
    final confirmation = _webConfirmation;
    if (confirmation == null) {
      throw FirebaseAuthException(
        code: 'session-expired',
        message: 'أعد طلب رمز التحقق.',
      );
    }
    return confirmation;
  }

  String _requireVerificationId() {
    final id = _verificationId;
    if (id == null) {
      throw FirebaseAuthException(
        code: 'session-expired',
        message: 'أعد طلب رمز التحقق.',
      );
    }
    return id;
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

  Object _mapLinkError(Object e) {
    if (e is FirebaseAuthException &&
        const {
          'provider-already-linked',
          'email-already-in-use',
          'credential-already-in-use',
        }.contains(e.code)) {
      return FirebaseAuthException(
        code: 'phone-already-registered',
        message: 'هذا الرقم مسجّل مسبقاً. سجّل الدخول بكلمة المرور.',
      );
    }
    return e;
  }
}
