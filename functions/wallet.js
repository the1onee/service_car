/**
 * محفظة الفني: الكتابة من Admin SDK فقط.
 * credit / adjustment للأدمن، وخصم العمولة عند إكمال الطلب بمعرّف ثابت.
 */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getApps, initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");

if (getApps().length === 0) initializeApp();
const db = getFirestore();

const DEFAULT_MIN_WALLET = 10000;

function roundMoney(n) {
  return Math.round(Number(n) * 100) / 100;
}

async function requireAdmin(request) {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError("unauthenticated", "يجب تسجيل الدخول.");
  const snap = await db.collection("users").doc(uid).get();
  if (!snap.exists || snap.data().role !== "admin") {
    throw new HttpsError("permission-denied", "هذه العملية للإدارة فقط.");
  }
  return uid;
}

async function getMinWalletBalance() {
  const snap = await db.collection("appSettings").doc("main").get();
  const n = snap.exists ? snap.data().minWalletBalance : null;
  return typeof n === "number" && Number.isFinite(n) ? n : DEFAULT_MIN_WALLET;
}

function requireTechnicianId(value) {
  if (typeof value !== "string" || !value.trim()) {
    throw new HttpsError("invalid-argument", "الفني مطلوب.");
  }
  return value.trim();
}

function requirePositive(value, label) {
  const n = Number(value);
  if (!Number.isFinite(n) || n <= 0) {
    throw new HttpsError("invalid-argument", `${label} يجب أن يكون أكبر من صفر.`);
  }
  return roundMoney(n);
}

/**
 * يطبّق حركة واحدة داخل معاملة: يحدّث الرصيد ويكتب walletEntries.
 * إن وُجد entryId وكانت الحركة موجودة لا يُخصم مرة ثانية.
 */
async function applyWalletChange({
  userId,
  type,
  amount,
  signedAmount,
  note,
  createdBy,
  jobId,
  entryId,
  minWallet,
}) {
  return db.runTransaction(async (tx) => {
    const userRef = db.collection("users").doc(userId);
    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) {
      throw new HttpsError("not-found", "الحساب غير موجود.");
    }
    const user = userSnap.data();
    if (user.role !== "technician") {
      throw new HttpsError("failed-precondition", "المحفظة للفنيين فقط.");
    }

    const entryRef = entryId
      ? db.collection("walletEntries").doc(entryId)
      : db.collection("walletEntries").doc();
    if (entryId) {
      const existing = await tx.get(entryRef);
      if (existing.exists) {
        return {
          ok: true,
          idempotent: true,
          entryId,
          balanceAfter: Number(existing.data().balanceAfter || user.walletBalance || 0),
        };
      }
    }

    const wallet = Number(user.walletBalance || 0);
    const next = roundMoney(wallet + signedAmount);
    tx.set(entryRef, {
      userId,
      type,
      amount: roundMoney(Math.abs(amount)),
      signedAmount: roundMoney(signedAmount),
      balanceAfter: next,
      jobId: jobId || null,
      note: (note || "").trim(),
      createdBy: createdBy || "",
      createdAt: FieldValue.serverTimestamp(),
    });
    const patch = { walletBalance: next };
    if (next < minWallet) patch.isOnline = false;
    tx.update(userRef, patch);
    return { ok: true, idempotent: false, entryId: entryRef.id, balanceAfter: next };
  });
}

exports.getMinWalletBalance = getMinWalletBalance;

exports.creditWallet = onCall(async (request) => {
  const adminUid = await requireAdmin(request);
  const userId = requireTechnicianId(request.data && request.data.userId);
  const amount = requirePositive(request.data && request.data.amount, "المبلغ");
  const note = typeof request.data?.note === "string" ? request.data.note : "";
  const minWallet = await getMinWalletBalance();
  return applyWalletChange({
    userId,
    type: "credit",
    amount,
    signedAmount: amount,
    note,
    createdBy: adminUid,
    minWallet,
  });
});

exports.adjustWallet = onCall(async (request) => {
  const adminUid = await requireAdmin(request);
  const userId = requireTechnicianId(request.data && request.data.userId);
  const signed = Number(request.data && request.data.signedAmount);
  const note = typeof request.data?.note === "string" ? request.data.note.trim() : "";
  if (!Number.isFinite(signed) || signed === 0) {
    throw new HttpsError("invalid-argument", "مبلغ التصحيح يجب أن يكون غير صفر.");
  }
  if (!note) {
    throw new HttpsError("invalid-argument", "ملاحظة التصحيح مطلوبة.");
  }
  const minWallet = await getMinWalletBalance();
  return applyWalletChange({
    userId,
    type: "adjustment",
    amount: Math.abs(signed),
    signedAmount: roundMoney(signed),
    note,
    createdBy: adminUid,
    minWallet,
  });
});

/** إكمال الطلب وخصم العمولة ذرياً. المعرّف commission_{jobId} يمنع التكرار. */
exports.completeJob = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError("unauthenticated", "يجب تسجيل الدخول.");

  const jobId = request.data && request.data.jobId;
  if (typeof jobId !== "string" || !jobId.trim()) {
    throw new HttpsError("invalid-argument", "الطلب مطلوب.");
  }
  const received = Number(request.data && request.data.receivedAmount);
  if (!Number.isFinite(received) || received < 0) {
    throw new HttpsError("invalid-argument", "المبلغ المستلم غير صالح.");
  }
  const warrantyEnabled = request.data && request.data.warrantyEnabled === true;

  const callerSnap = await db.collection("users").doc(uid).get();
  const isAdmin = callerSnap.exists && callerSnap.data().role === "admin";
  const minWallet = await getMinWalletBalance();

  return db.runTransaction(async (tx) => {
    const jobRef = db.collection("jobs").doc(jobId.trim());
    const jobSnap = await tx.get(jobRef);
    if (!jobSnap.exists) throw new HttpsError("not-found", "الطلب غير موجود.");
    const job = jobSnap.data();
    const techId = job.technicianId;
    if (!techId) throw new HttpsError("failed-precondition", "لا يوجد فني معيّن.");
    if (techId !== uid && !isAdmin) {
      throw new HttpsError("permission-denied", "لا يمكنك إكمال هذا الطلب.");
    }
    if (job.status !== "inProgress" && job.status !== "completed") {
      throw new HttpsError("failed-precondition", "الطلب ليس قيد التنفيذ.");
    }

    const entryId = `commission_${jobId.trim()}`;
    const entryRef = db.collection("walletEntries").doc(entryId);
    const entrySnap = await tx.get(entryRef);
    const techRef = db.collection("users").doc(techId);
    const techSnap = await tx.get(techRef);

    const rateRaw = job.commissionRate;
    const rate = typeof rateRaw === "number" ? Math.min(1, Math.max(0, rateRaw)) : 0.1;
    const commission = roundMoney(received * rate);

    const jobPatch = {
      receivedAmount: roundMoney(received),
      commissionAmount: commission,
      status: "completed",
      "warranty.startsAt": warrantyEnabled ? Timestamp.now() : job.warranty?.startsAt || null,
    };

    if (entrySnap.exists || job.status === "completed") {
      if (job.status !== "completed") tx.update(jobRef, jobPatch);
      return {
        ok: true,
        idempotent: true,
        commission,
        balanceAfter: entrySnap.exists
          ? Number(entrySnap.data().balanceAfter || 0)
          : Number(techSnap.data()?.walletBalance || 0),
      };
    }

    const wallet = Number(techSnap.data()?.walletBalance || 0);
    const next = roundMoney(wallet - commission);
    tx.set(entryRef, {
      userId: techId,
      type: "commission",
      amount: commission,
      signedAmount: -commission,
      balanceAfter: next,
      jobId: jobId.trim(),
      note: "عمولة إكمال الطلب",
      createdBy: uid,
      createdAt: FieldValue.serverTimestamp(),
    });
    const techPatch = { walletBalance: next };
    if (next < minWallet) techPatch.isOnline = false;
    tx.update(techRef, techPatch);
    tx.update(jobRef, jobPatch);
    return { ok: true, idempotent: false, commission, balanceAfter: next };
  });
});
