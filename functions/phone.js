/**
 * نسخة مطابقة لـ lib/core/phone.dart — أي تغيير هنا يجب أن يقابله تغيير هناك،
 * وفي C:\barrr-admin\src\lib\phone.ts، وإلا اختلف البريد الداخلي بين التطبيق
 * ولوحة التحكم ولم يعمل تسجيل الدخول.
 */

/** نطاق داخلي لا يُرسل إليه بريد فعلي؛ يربط كلمة المرور برقم الهاتف. */
const AUTH_EMAIL_DOMAIN = "phone.barrr.app";

/** تطبيع أرقام العراق إلى صيغة E.164 (+964…). */
function normalizeIraqiPhone(raw) {
  let p = String(raw).trim().replace(/[\s\-()]/g, "");
  // تحويل الأرقام العربية الهندية (٠-٩) إلى لاتينية.
  p = p.replace(/[\u0660-\u0669]/g, (c) => String(c.charCodeAt(0) - 0x0660));
  if (p === "") return p;
  if (p.startsWith("00")) p = `+${p.slice(2)}`;
  if (p.startsWith("+964")) return p;
  if (p.startsWith("964")) return `+${p}`;
  if (p.startsWith("0")) return `+964${p.slice(1)}`;
  if (p.startsWith("7") && p.length === 10) return `+964${p}`;
  if (!p.startsWith("+")) return `+964${p}`;
  return p;
}

function looksLikeIraqiMobile(e164) {
  return /^\+9647\d{9}$/.test(e164);
}

/** البريد الداخلي المقابل للرقم، لتخزين كلمة المرور في Firebase Auth. */
function phoneAuthEmail(e164) {
  return `${e164.replace(/\+/g, "")}@${AUTH_EMAIL_DOMAIN}`;
}

module.exports = { normalizeIraqiPhone, looksLikeIraqiMobile, phoneAuthEmail };
