/// نطاق داخلي لا يُرسل إليه بريد فعلي؛ يُستخدم فقط لربط كلمة المرور برقم الهاتف
/// لأن Firebase لا يدعم كلمة مرور مع مزوّد الهاتف.
const _authEmailDomain = 'phone.barrr.app';

/// تطبيع أرقام العراق إلى صيغة E.164 (+964…).
String normalizeIraqiPhone(String raw) {
  var p = raw.trim().replaceAll(RegExp(r'[\s\-()]'), '');
  // تحويل الأرقام العربية الهندية (٠-٩) إلى لاتينية.
  p = p.replaceAllMapped(
    RegExp(r'[\u0660-\u0669]'),
    (m) => '${m.group(0)!.codeUnitAt(0) - 0x0660}',
  );
  if (p.isEmpty) return p;
  if (p.startsWith('00')) p = '+${p.substring(2)}';
  if (p.startsWith('+964')) return p;
  if (p.startsWith('964')) return '+$p';
  if (p.startsWith('0')) return '+964${p.substring(1)}';
  if (p.startsWith('7') && p.length == 10) return '+964$p';
  if (!p.startsWith('+')) return '+964$p';
  return p;
}

bool looksLikeIraqiMobile(String e164) {
  return RegExp(r'^\+9647\d{9}$').hasMatch(e164);
}

/// صيغة عرض مقروءة: ‎0770 123 4567‎.
String prettyIraqiPhone(String e164) {
  if (!looksLikeIraqiMobile(e164)) return e164;
  final local = '0${e164.substring(4)}';
  return '${local.substring(0, 4)} ${local.substring(4, 7)} ${local.substring(7)}';
}

/// البريد الداخلي المقابل للرقم، لتخزين كلمة المرور في Firebase Auth.
String phoneAuthEmail(String e164) =>
    '${e164.replaceAll('+', '')}@$_authEmailDomain';
