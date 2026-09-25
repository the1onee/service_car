const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { getApps, initializeApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

if (getApps().length === 0) initializeApp();
const db = getFirestore();

const EMERGENCY_IDS = new Set(["towing", "locks", "fuel"]);
const EMERGENCY_SECONDS = 30;
const QUOTE_SECONDS = 150;
const EMERGENCY_TECHS = 2;
const QUOTE_TECHS = 8;
const MAX_QUOTES = 3;
const MAX_ROUNDS = 3;
const MAX_KM = 25;
const walletFns = require("./wallet");

function isEmergencyJob(job) {
  if (job.matchingMode === "emergency") return true;
  if (job.matchingMode === "quotes") return false;
  return EMERGENCY_IDS.has(job.serviceId);
}

function haversineKm(lat1, lng1, lat2, lng2) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) * Math.cos((lat2 * Math.PI) / 180) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

async function notify(tokens, title, body, data) {
  const list = [...new Set(tokens.filter(Boolean))];
  if (!list.length) return { successCount: 0, failureCount: 0 };
  let successCount = 0;
  let failureCount = 0;
  const messaging = getMessaging();
  const payloadData = Object.fromEntries(
    Object.entries(data || {}).map(([k, v]) => [k, String(v)])
  );
  for (let i = 0; i < list.length; i += 500) {
    const chunk = list.slice(i, i + 500);
    const res = await messaging.sendEachForMulticast({
      tokens: chunk,
      notification: { title, body },
      data: payloadData,
    });
    successCount += res.successCount;
    failureCount += res.failureCount;
  }
  return { successCount, failureCount };
}

function audienceRoles(audience) {
  if (audience === "customers") return ["customer"];
  if (audience === "technicians") return ["technician"];
  return ["customer", "technician"];
}

async function collectFcmTokensForRoles(roles) {
  const tokens = [];
  for (const role of roles) {
    const snap = await db.collection("users").where("role", "==", role).get();
    snap.docs.forEach((d) => {
      const token = d.data().fcmToken;
      if (typeof token === "string" && token.trim()) tokens.push(token.trim());
    });
  }
  return tokens;
}

async function expirePending(jobId) {
  const pending = await db
    .collection("jobOffers")
    .where("jobId", "==", jobId)
    .where("status", "==", "pending")
    .get();
  if (pending.empty) return;
  const batch = db.batch();
  pending.docs.forEach((d) => batch.update(d.ref, { status: "expired" }));
  await batch.commit();
}

async function assignOffer(jobRef, offerSnap) {
  const offer = offerSnap.data();
  await jobRef.update({
    technicianId: offer.technicianId,
    technicianName: offer.technicianName || "فني",
    initialPrice: Number(offer.initialPrice || 0),
    status: "quoted",
  });
  await offerSnap.ref.update({ status: "accepted" });
  const others = await db.collection("jobOffers").where("jobId", "==", offer.jobId).get();
  const batch = db.batch();
  others.docs.forEach((d) => {
    if (d.id === offerSnap.id) return;
    const st = d.data().status;
    if (st === "submitted" || st === "pending") batch.update(d.ref, { status: "expired" });
  });
  await batch.commit();
}

async function closeQuoteWindow(jobId) {
  const jobRef = db.collection("jobs").doc(jobId);
  const jobSnap = await jobRef.get();
  if (!jobSnap.exists) return { ok: false };
  const job = jobSnap.data();
  if (job.technicianId || job.status !== "offerPending" || isEmergencyJob(job)) {
    return { ok: false };
  }
  await expirePending(jobId);
  const submitted = await db
    .collection("jobOffers")
    .where("jobId", "==", jobId)
    .where("status", "==", "submitted")
    .get();
  if (submitted.empty) {
    await maybeRedispatchInternal(jobId, false);
    return { ok: true, action: "redispatch" };
  }
  if (submitted.size === 1) {
    await assignOffer(jobRef, submitted.docs[0]);
    const customer = await db.collection("users").doc(job.customerId).get();
    await notify([customer.data()?.fcmToken], "عرض واحد", "تم تعيين الفني تلقائياً", {
      jobId,
      type: "quoted",
    });
    return { ok: true, action: "auto" };
  }
  await jobRef.update({ status: "comparing" });
  const customer = await db.collection("users").doc(job.customerId).get();
  await notify([customer.data()?.fcmToken], "قارن العروض", "اختر الفني المناسب", {
    jobId,
    type: "comparing",
  });
  return { ok: true, action: "compare" };
}

async function maybeRedispatchInternal(jobId, expire = true) {
  const jobRef = db.collection("jobs").doc(jobId);
  const jobSnap = await jobRef.get();
  if (!jobSnap.exists) return;
  const job = jobSnap.data();
  if (job.technicianId) return;
  if (!["offerPending", "dispatching", "noTechnician"].includes(job.status)) return;
  if (expire) await expirePending(jobId);
  if (job.status === "noTechnician") {
    await jobRef.update({ dispatchRound: 1, status: "dispatching" });
    return dispatchJobInternal(jobId);
  }
  const round = job.dispatchRound || 1;
  const next = job.status === "dispatching" ? round : round + 1;
  if (next > MAX_ROUNDS) {
    await jobRef.update({ status: "noTechnician" });
    const customer = await db.collection("users").doc(job.customerId).get();
    await notify([customer.data()?.fcmToken], "لا يوجد فني", "لم يصل عرض مناسب", { jobId });
    return;
  }
  await jobRef.update({ dispatchRound: next, status: "dispatching" });
  return dispatchJobInternal(jobId);
}

async function dispatchJobInternal(jobId) {
  const jobRef = db.collection("jobs").doc(jobId);
  const jobSnap = await jobRef.get();
  if (!jobSnap.exists) return { ok: false, reason: "missing" };
  const job = jobSnap.data();
  if (job.technicianId) return { ok: false, reason: "busy" };
  if (!["dispatching", "offerPending", "noTechnician"].includes(job.status)) {
    return { ok: false, reason: "busy" };
  }

  const emergency = isEmergencyJob(job);
  const techs = await db
    .collection("users")
    .where("role", "==", "technician")
    .get();

  const previous = await db.collection("jobOffers").where("jobId", "==", jobId).get();
  const livePending = previous.docs.filter((d) => {
    const data = d.data();
    if (data.status !== "pending") return false;
    const exp = data.expiresAt?.toDate?.();
    return !exp || exp > new Date();
  });
  if (livePending.length) {
    if (job.status !== "offerPending") {
      await jobRef.update({ status: "offerPending" });
    }
    return { ok: true, reason: "already" };
  }
  const used = new Set(previous.docs.map((d) => d.data().technicianId));
  const minWallet = await walletFns.getMinWalletBalance();

  const origin = job.approxLocation;
  const neededVehicle = typeof job.vehicleTypeId === "string" ? job.vehicleTypeId : "";
  const ranked = techs.docs
    .map((d) => {
      const data = d.data();
      const geo = data.geo;
      const km = geo
        ? haversineKm(origin.latitude, origin.longitude, geo.latitude, geo.longitude)
        : MAX_KM;
      const vehicleTypeIds = Array.isArray(data.vehicleTypeIds)
        ? data.vehicleTypeIds.filter((id) => typeof id === "string")
        : [];
      const serviceIds = Array.isArray(data.serviceIds)
        ? data.serviceIds.filter((id) => typeof id === "string")
        : [];
      return {
        id: d.id,
        online: data.isOnline === true,
        km,
        token: data.fcmToken,
        name: data.name || "فني",
        rating: data.ratingAvg || 5,
        verified: !!data.verified,
        wallet: Number(data.walletBalance || 0),
        vehicleTypeIds,
        serviceIds,
      };
    })
    .filter((t) => t.online)
    .filter((t) => !t.serviceIds.length || t.serviceIds.includes(job.serviceId))
    .filter((t) => t.km <= MAX_KM)
    .filter((t) => t.verified)
    .filter((t) => t.wallet >= minWallet)
    .filter((t) => !used.has(t.id))
    .filter((t) => !neededVehicle || !t.vehicleTypeIds.length || t.vehicleTypeIds.includes(neededVehicle))
    .sort((a, b) => a.km - b.km)
    .slice(0, emergency ? EMERGENCY_TECHS : QUOTE_TECHS);

  if (!ranked.length) {
    await jobRef.update({ status: "noTechnician" });
    return { ok: false, reason: "none" };
  }

  const seconds = emergency ? EMERGENCY_SECONDS : QUOTE_SECONDS;
  const expires = Timestamp.fromDate(new Date(Date.now() + seconds * 1000));
  const batch = db.batch();
  for (const t of ranked) {
    batch.set(db.collection("jobOffers").doc(), {
      jobId,
      technicianId: t.id,
      status: "pending",
      expiresAt: expires,
      serviceTitle: job.serviceTitle || job.serviceId,
      vehicleTypeTitle: job.vehicleTypeTitle || null,
      approxLocation: job.approxLocation,
      round: job.dispatchRound || 1,
      technicianName: t.name,
      ratingAvg: t.rating,
      distanceKm: t.km,
      verified: t.verified,
    });
  }
  batch.update(jobRef, { status: "offerPending", expiresAt: expires, matchingMode: emergency ? "emergency" : "quotes" });
  await batch.commit();
  await notify(
    ranked.map((t) => t.token),
    "طلب جديد",
    emergency ? "لديك 30 ثانية لقبول الطلب وإدخال السعر المبدئي" : "أرسل سعراً مبدئياً خلال دقائق ليراه العميل",
    { jobId, type: "offer" }
  );
  return { ok: true, count: ranked.length };
}

exports.dispatchJob = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "login");
  const jobId = request.data.jobId;
  if (!jobId) throw new HttpsError("invalid-argument", "jobId");
  return dispatchJobInternal(jobId);
});

exports.onWindowExpired = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "login");
  const jobId = request.data.jobId;
  if (!jobId) throw new HttpsError("invalid-argument", "jobId");
  const job = (await db.collection("jobs").doc(jobId).get()).data();
  if (!job) return { ok: false };
  if (isEmergencyJob(job)) {
    await maybeRedispatchInternal(jobId);
    return { ok: true };
  }
  return closeQuoteWindow(jobId);
});

exports.selectOffer = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "login");
  const { jobId, offerId } = request.data || {};
  if (!jobId || !offerId) throw new HttpsError("invalid-argument", "data");
  const jobRef = db.collection("jobs").doc(jobId);
  const jobSnap = await jobRef.get();
  const job = jobSnap.data();
  if (!job || job.customerId !== request.auth.uid) throw new HttpsError("permission-denied", "job");
  if (job.technicianId || !["comparing", "offerPending"].includes(job.status)) {
    return { ok: false };
  }
  const offerSnap = await db.collection("jobOffers").doc(offerId).get();
  if (!offerSnap.exists || offerSnap.data().jobId !== jobId || offerSnap.data().status !== "submitted") {
    return { ok: false };
  }
  await assignOffer(jobRef, offerSnap);
  return { ok: true };
});

exports.onJobCreated = onDocumentCreated("jobs/{jobId}", async (event) => {
  const jobId = event.params.jobId;
  const data = event.data?.data();
  if (!data || data.status !== "dispatching") return;
  await dispatchJobInternal(jobId);
});

exports.onOfferCreated = onDocumentCreated(
  { document: "jobOffers/{offerId}", timeoutSeconds: 180 },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const offer = snap.data();
    const jobSnap = await db.collection("jobs").doc(offer.jobId).get();
    if (!jobSnap.exists) return;
    const job = jobSnap.data();
    if (!isEmergencyJob(job)) return;

    await new Promise((r) => setTimeout(r, (EMERGENCY_SECONDS + 1) * 1000));
    const fresh = await snap.ref.get();
    if (!fresh.exists) return;
    if (fresh.data().status !== "pending") return;
    await snap.ref.update({ status: "expired" });

    const latestJob = (await db.collection("jobs").doc(offer.jobId).get()).data();
    if (!latestJob || latestJob.technicianId || latestJob.status !== "offerPending") return;

    const pending = await db
      .collection("jobOffers")
      .where("jobId", "==", offer.jobId)
      .where("status", "==", "pending")
      .get();
    if (!pending.empty) return;
    await maybeRedispatchInternal(offer.jobId, false);
  }
);

exports.onQuoteWindow = onDocumentUpdated(
  { document: "jobs/{jobId}", timeoutSeconds: 180 },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (!after || after.status !== "offerPending" || isEmergencyJob(after)) return;
    if (before.status === "offerPending") return;
    const exp = after.expiresAt?.toDate?.() || new Date(Date.now() + QUOTE_SECONDS * 1000);
    const wait = exp.getTime() - Date.now() + 1000;
    if (wait > 0) await new Promise((r) => setTimeout(r, Math.min(wait, 170000)));
    await closeQuoteWindow(event.params.jobId);
  }
);

exports.acceptOffer = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "login");
  const { offerId, initialPrice } = request.data || {};
  const uid = request.auth.uid;
  if (!offerId || !initialPrice) throw new HttpsError("invalid-argument", "data");
  const price = Math.round(Number(initialPrice));
  if (!Number.isFinite(price) || price < 3000 || price % 1000 !== 0) {
    throw new HttpsError("invalid-argument", "أقل مبلغ 3000 ويجب أن ينتهي بـ 000");
  }

  const user = await db.collection("users").doc(uid).get();
  const userData = user.data() || {};
  const minWallet = await walletFns.getMinWalletBalance();
  if (!userData.verified || Number(userData.walletBalance || 0) < minWallet) {
    throw new HttpsError("failed-precondition", "wallet_or_verify");
  }
  const technicianName = userData.name || "فني";

  const offerRef = db.collection("jobOffers").doc(offerId);
  const offerSnap = await offerRef.get();
  if (!offerSnap.exists) return { ok: false };
  const offer = offerSnap.data();
  const jobRef = db.collection("jobs").doc(offer.jobId);
  const job = (await jobRef.get()).data();
  if (!job) return { ok: false };
  const emergency = isEmergencyJob(job);

  if (emergency) {
    const won = await db.runTransaction(async (tx) => {
      const oSnap = await tx.get(offerRef);
      if (!oSnap.exists) return false;
      const o = oSnap.data();
      if (o.technicianId !== uid || o.status !== "pending") return false;
      if (o.expiresAt.toDate() < new Date()) {
        tx.update(offerRef, { status: "expired" });
        return false;
      }
      const jSnap = await tx.get(jobRef);
      const j = jSnap.data();
      if (j.technicianId) return false;
      tx.update(jobRef, {
        technicianId: uid,
        technicianName,
        initialPrice: Number(initialPrice),
        status: "quoted",
      });
      tx.update(offerRef, { status: "accepted", initialPrice: Number(initialPrice) });
      return o.jobId;
    });
    if (!won) return { ok: false };
    await expirePending(won);
    const latest = (await db.collection("jobs").doc(won).get()).data();
    const customer = await db.collection("users").doc(latest.customerId).get();
    await notify(
      [customer.data()?.fcmToken],
      "فني قبل الطلب",
      `${technicianName} عرض سعراً مبدئياً ${initialPrice}`,
      { jobId: won, type: "quoted" }
    );
    return { ok: true };
  }

  const submittedOk = await db.runTransaction(async (tx) => {
    const oSnap = await tx.get(offerRef);
    if (!oSnap.exists) return false;
    const o = oSnap.data();
    if (o.technicianId !== uid || o.status !== "pending") return false;
    if (o.expiresAt.toDate() < new Date()) {
      tx.update(offerRef, { status: "expired" });
      return false;
    }
    const jSnap = await tx.get(jobRef);
    if (jSnap.data().technicianId) return false;
    if (jSnap.data().status !== "offerPending") return false;
    tx.update(offerRef, {
      status: "submitted",
      initialPrice: Number(initialPrice),
      technicianName,
    });
    return true;
  });
  if (!submittedOk) return { ok: false };

  const submitted = await db
    .collection("jobOffers")
    .where("jobId", "==", offer.jobId)
    .where("status", "==", "submitted")
    .get();
  if (submitted.size >= MAX_QUOTES) {
    await closeQuoteWindow(offer.jobId);
  } else {
    const customer = await db.collection("users").doc(job.customerId).get();
    await notify(
      [customer.data()?.fcmToken],
      "عرض جديد",
      `${technicianName} أرسل سعراً مبدئياً`,
      { jobId: offer.jobId, type: "quote" }
    );
  }
  return { ok: true };
});

exports.onJobStatus = onDocumentUpdated("jobs/{jobId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (!after || before.status === after.status) return;
  const jobId = event.params.jobId;
  const customer = await db.collection("users").doc(after.customerId).get();
  const tech = after.technicianId
    ? await db.collection("users").doc(after.technicianId).get()
    : null;
  const cToken = customer.data()?.fcmToken;
  const tToken = tech?.data()?.fcmToken;

  const messages = {
    enRoute: { to: "tech", title: "العميل وافق", body: "توجه إلى موقع العميل الحقيقي" },
    finalQuote: { to: "cust", title: "سعر نهائي", body: `السعر النهائي ${after.finalPrice || ""}` },
    inProgress: { to: "tech", title: "بدء العمل", body: "العميل وافق على السعر النهائي" },
    completed: { to: "cust", title: "انتهت المهمة", body: "قيّم الفني واطلع على الضمان" },
    comparing: { to: "cust", title: "قارن العروض", body: "اختر الفني حسب السعر والتقييم والمسافة" },
  };
  const msg = messages[after.status];
  if (!msg) return;
  const token = msg.to === "tech" ? tToken : cToken;
  await notify([token], msg.title, msg.body, { jobId, type: after.status });
});

/** بث إشعار أدمن: يُفعَّل عند إنشاء مستند notifications بدون userId ومع audience. */
exports.onAdminNotificationCreated = onDocumentCreated(
  "notifications/{id}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data() || {};
    if (data.userId) return;
    if (typeof data.audience !== "string" || !data.audience.trim()) return;
    if (data.status && data.status !== "pending") return;

    const title = typeof data.title === "string" ? data.title.trim() : "";
    const body = typeof data.body === "string" ? data.body.trim() : "";
    if (!title || !body) {
      await snap.ref.update({
        status: "failed",
        sentAt: Timestamp.now(),
        successCount: 0,
        failureCount: 0,
        error: "title_or_body_missing",
      });
      return;
    }

    try {
      const tokens = await collectFcmTokensForRoles(audienceRoles(data.audience));
      if (!tokens.length) {
        await snap.ref.update({
          status: "empty",
          sentAt: Timestamp.now(),
          successCount: 0,
          failureCount: 0,
        });
        return;
      }
      const result = await notify(tokens, title, body, {
        type: "admin",
        notificationId: event.params.id,
        audience: data.audience,
      });
      await snap.ref.update({
        status: result.failureCount > 0 && result.successCount === 0 ? "failed" : "sent",
        sentAt: Timestamp.now(),
        successCount: result.successCount,
        failureCount: result.failureCount,
      });
    } catch (err) {
      await snap.ref.update({
        status: "failed",
        sentAt: Timestamp.now(),
        successCount: 0,
        failureCount: 0,
        error: String((err && err.message) || err),
      });
    }
  }
);

// عمليات لوحة التحكم التي تحتاج Admin SDK. تُستدعى بعد initializeApp أعلاه.
const adminUsers = require("./admin_users");
exports.createUserAccount = adminUsers.createUserAccount;
exports.deleteUserAccount = adminUsers.deleteUserAccount;
exports.setUserPassword = adminUsers.setUserPassword;
exports.setUserDisabled = adminUsers.setUserDisabled;
exports.creditWallet = walletFns.creditWallet;
exports.adjustWallet = walletFns.adjustWallet;
exports.completeJob = walletFns.completeJob;
