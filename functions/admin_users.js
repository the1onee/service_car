/**
 * عمليات الحسابات التي تحتاج Admin SDK، تُستدعى من لوحة التحكم فقط.
 *
 * إنشاء حساب من المتصفح غير ممكن: createUserWithEmailAndPassword يُسجّل دخول
 * الحساب الجديد ويُخرج الأدمن من حسابه. Admin SDK ينشئ الحساب بالبريد الداخلي
 * ويربط الرقم دون رمز SMS، فتكون النتيجة مطابقة لحساب يُنشئه التطبيق.
 *
 * المنطقة الافتراضية (us-central1) مقصودة: التطبيق يستدعي الدوال عبر
 * FirebaseFunctions.instance، وتغيير المنطقة يكسر بقية الدوال.
 */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getApps, initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { normalizeIraqiPhone, looksLikeIraqiMobile, phoneAuthEmail } = require("./phone");

if (getApps().length === 0) initializeApp();
const db = getFirestore();
const auth = getAuth();

const ROLES = ["customer", "technician", "admin"];

/** يتحقق أن صاحب الطلب مسجّل دخول ودوره admin في users/{uid}. */
async function requireAdmin(request) {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError("unauthenticated", "يجب تسجيل الدخول.");
  const snap = await db.collection("users").doc(uid).get();
  if (!snap.exists || snap.data().role !== "admin") {
    throw new HttpsError("permission-denied", "هذه العملية للإدارة فقط.");
  }
  return uid;
}

function requireString(value, field) {
  if (typeof value !== "string" || value.trim() === "") {
    throw new HttpsError("invalid-argument", `الحقل ${field} مطلوب.`);
  }
  return value.trim();
}

function requireRole(value) {
  const role = requireString(value, "role");
  if (!ROLES.includes(role)) throw new HttpsError("invalid-argument", "الدور غير معروف.");
  return role;
}

function requirePhone(value) {
  const e164 = normalizeIraqiPhone(requireString(value, "phone"));
  if (!looksLikeIraqiMobile(e164)) {
    throw new HttpsError("invalid-argument", "رقم الهاتف غير صالح. مثال: 07701234567");
  }
  return e164;
}

function requirePassword(value) {
  const password = requireString(value, "password");
  if (password.length < 6) {
    throw new HttpsError("invalid-argument", "كلمة المرور يجب أن تكون 6 أحرف على الأقل.");
  }
  return password;
}

/** يحوّل أخطاء Firebase Auth إلى رسائل عربية تُعرض في اللوحة. */
function mapAuthError(error) {
  const code = (error && error.code) || "";
  if (code === "auth/email-already-exists" || code === "auth/phone-number-already-exists") {
    return new HttpsError("already-exists", "هذا الرقم مسجّل مسبقاً.");
  }
  if (code === "auth/invalid-password") {
    return new HttpsError("invalid-argument", "كلمة المرور غير صالحة.");
  }
  if (code === "auth/user-not-found") {
    return new HttpsError("not-found", "الحساب غير موجود.");
  }
  return new HttpsError("internal", "تعذّر إكمال العملية.");
}

/** إنشاء حساب عميل أو فني من لوحة التحكم. */
exports.createUserAccount = onCall(async (request) => {
  const adminUid = await requireAdmin(request);
  const data = request.data || {};

  const role = requireRole(data.role);
  const e164 = requirePhone(data.phone);
  const password = requirePassword(data.password);
  const name = requireString(data.name, "name");
  const address = typeof data.address === "string" ? data.address.trim() : "";
  const serviceIds = Array.isArray(data.serviceIds)
    ? data.serviceIds.filter((id) => typeof id === "string")
    : [];
  // الفني يبقى بانتظار التوثيق إلا إذا اعتمده الأدمن عند الإنشاء.
  const approved = data.approved === true || role !== "technician";
  const walletBalance = typeof data.walletBalance === "number" ? data.walletBalance : 0;

  let uid;
  try {
    const user = await auth.createUser({
      email: phoneAuthEmail(e164),
      emailVerified: false,
      password,
      phoneNumber: e164,
      displayName: name,
    });
    uid = user.uid;
  } catch (error) {
    throw mapAuthError(error);
  }

  try {
    // نفس شكل المستند الذي يكتبه التطبيق (AppUser.toMap) حتى تتوحّد البيانات.
    await db.collection("users").doc(uid).set({
      role,
      name,
      phone: e164,
      address,
      ratingAvg: 5,
      ratingCount: 0,
      fcmToken: null,
      isOnline: false,
      geo: null,
      serviceIds,
      verified: approved,
      verificationStatus: approved ? "approved" : "pending",
      walletBalance,
      createdAt: FieldValue.serverTimestamp(),
      createdBy: adminUid,
    });
  } catch (error) {
    // لا نترك حساب مصادقة بلا ملف تعريف.
    await auth.deleteUser(uid).catch(() => undefined);
    throw error;
  }

  return { uid };
});

/** حذف حساب نهائياً: المصادقة وملف التعريف معاً. */
exports.deleteUserAccount = onCall(async (request) => {
  const adminUid = await requireAdmin(request);
  const uid = requireString(request.data && request.data.uid, "uid");
  if (uid === adminUid) {
    throw new HttpsError("failed-precondition", "لا يمكنك حذف حسابك الحالي.");
  }

  try {
    await auth.deleteUser(uid);
  } catch (error) {
    // الحساب قد يكون محذوفاً من المصادقة أصلاً، نكمل لحذف المستند.
    if ((error && error.code) !== "auth/user-not-found") throw mapAuthError(error);
  }
  await db.collection("users").doc(uid).delete();

  return { uid };
});

/** تعيين كلمة مرور جديدة لمستخدم (دعم فني). */
exports.setUserPassword = onCall(async (request) => {
  await requireAdmin(request);
  const uid = requireString(request.data && request.data.uid, "uid");
  const password = requirePassword(request.data && request.data.password);

  try {
    await auth.updateUser(uid, { password });
  } catch (error) {
    throw mapAuthError(error);
  }
  return { uid };
});

/** تعطيل أو تفعيل حساب دون حذفه. */
exports.setUserDisabled = onCall(async (request) => {
  const adminUid = await requireAdmin(request);
  const uid = requireString(request.data && request.data.uid, "uid");
  const disabled = (request.data && request.data.disabled) === true;
  if (uid === adminUid) {
    throw new HttpsError("failed-precondition", "لا يمكنك تعطيل حسابك الحالي.");
  }

  try {
    await auth.updateUser(uid, { disabled });
  } catch (error) {
    throw mapAuthError(error);
  }
  const patch = { disabled };
  if (disabled) patch.isOnline = false;
  await db.collection("users").doc(uid).set(patch, { merge: true });

  return { uid, disabled };
});
