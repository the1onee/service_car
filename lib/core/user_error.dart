import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:barrr/core/strings.dart';

const _generic = 'تعذّر إكمال العملية. حاول مرة أخرى.';
const _network = 'لا يوجد اتصال بالإنترنت. تحقق من الشبكة ثم أعد المحاولة.';

/// يسجّل التفاصيل للمطور دون عرضها للمستخدم.
void logUserError(Object error, [StackTrace? stack, String? context]) {
  final tag = context == null ? 'user_error' : 'user_error:$context';
  debugPrint('$tag: $error');
  if (stack != null) debugPrint(stack.toString());
}

/// رسالة آمنة للمستخدم — لا تعرض `toString()` الخام في الإRelease.
String userFacingError(
  Object error, {
  String? prefix,
  String? fallback,
}) {
  logUserError(error, null, prefix);

  final core = _mapError(error, fallback: fallback);
  if (prefix == null || prefix.trim().isEmpty) return core;
  if (core == _generic || core == (fallback ?? _generic)) {
    return prefix.trim();
  }
  return '${prefix.trim()} $core';
}

String _mapError(Object error, {String? fallback}) {
  if (error is FormatException) {
    final msg = error.message.trim();
    if (msg.isNotEmpty && _safeToShow(msg)) return msg;
    return fallback ?? _generic;
  }
  if (error is FirebaseAuthException) {
    return _authMessage(error);
  }
  if (error is FirebaseException) {
    return _firebaseMessage(error, fallback);
  }
  if (error is SocketException || error is TimeoutException) {
    return _network;
  }
  if (error is IOException) {
    return _network;
  }
  if (kDebugMode) {
    final raw = error.toString().trim();
    if (raw.isNotEmpty && raw.length < 120 && _safeToShow(raw)) return raw;
  }
  return fallback ?? _generic;
}

bool _safeToShow(String text) {
  final lower = text.toLowerCase();
  if (lower.contains('exception') ||
      lower.contains('firebase') ||
      lower.contains('stack') ||
      lower.contains('permission-denied') ||
      lower.contains('cloud_firestore')) {
    return false;
  }
  return true;
}

String _firebaseMessage(FirebaseException e, String? fallback) {
  switch (e.code) {
    case 'permission-denied':
      return 'لا تملك صلاحية لهذه العملية.';
    case 'unavailable':
    case 'network-request-failed':
      return _network;
    case 'not-found':
      return 'العنصر المطلوب غير موجود.';
    case 'already-exists':
      return 'هذا السجل موجود مسبقاً.';
    case 'resource-exhausted':
      return 'الخدمة مشغولة حالياً. حاول بعد قليل.';
    case 'deadline-exceeded':
    case 'cancelled':
      return 'انتهت مهلة العملية. أعد المحاولة.';
    default:
      if (kDebugMode) {
        final msg = e.message?.trim() ?? '';
        if (msg.isNotEmpty && _safeToShow(msg)) return msg;
        return '${fallback ?? _generic} (${e.code})';
      }
      return fallback ?? _generic;
  }
}

String _authMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-phone-number':
      return 'رقم الهاتف غير صالح. استخدم صيغة 07701234567';
    case 'invalid-credential':
    case 'wrong-password':
      return 'رقم الهاتف أو كلمة المرور غير صحيحة.';
    case 'invalid-email':
      final msg = e.message?.trim() ?? '';
      return msg.isNotEmpty && _safeToShow(msg)
          ? msg
          : 'البريد الإلكتروني غير صالح.';
    case 'user-not-found':
      return AppStrings.resetEmailSentBody;
    case 'user-disabled':
      return 'هذا الحساب موقوف. راجع الإدارة.';
    case 'phone-already-registered':
      return 'هذا الحساب مسجّل مسبقاً. سجّل الدخول.';
    case 'too-many-requests':
      return 'محاولات كثيرة. انتظر قليلاً ثم أعد المحاولة.';
    case 'google-sign-in-failed':
      final msg = e.message?.trim() ?? '';
      return msg.isNotEmpty && _safeToShow(msg)
          ? msg
          : 'تعذّر تسجيل الدخول عبر Google.';
    case 'operation-not-allowed':
      return kReleaseMode
          ? 'تعذّر تسجيل الدخول. تواصل مع الدعم.'
          : 'مزوّد الدخول غير مفعّل في Firebase.';
    case 'network-request-failed':
      return _network;
    case 'weak-password':
      return 'كلمة المرور ضعيفة، استخدم ٦ أحرف على الأقل.';
    case 'internal-error':
      return _generic;
    default:
      if (kDebugMode) {
        final msg = e.message?.trim() ?? '';
        if (msg.length >= 12 && _safeToShow(msg)) return msg;
        return 'تعذر إكمال العملية (${e.code}). حاول مرة أخرى.';
      }
      return _generic;
  }
}
