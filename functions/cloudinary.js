const crypto = require("crypto");
const { onCall, HttpsError } = require("firebase-functions/v2/https");

/**
 * يُرجع معاملات رفع موقّع لـ Cloudinary (بدون كشف api_secret للعميل).
 * عيّن عند النشر:
 *   CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET
 */
exports.getCloudinaryUploadSign = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول للرفع.");
  }

  const cloudName = String(process.env.CLOUDINARY_CLOUD_NAME || "").trim();
  const apiKey = String(process.env.CLOUDINARY_API_KEY || "").trim();
  const apiSecret = String(process.env.CLOUDINARY_API_SECRET || "").trim();
  if (!cloudName || !apiKey || !apiSecret) {
    throw new HttpsError(
      "failed-precondition",
      "Cloudinary غير مضبوط على الخادم (CLOUDINARY_* env)."
    );
  }

  const rawFolder = request.data && request.data.folder;
  const folder = String(rawFolder || "barrr")
    .trim()
    .slice(0, 120)
    .replace(/[^a-zA-Z0-9/_-]/g, "");
  if (!folder) {
    throw new HttpsError("invalid-argument", "مجلد الرفع غير صالح.");
  }

  const timestamp = Math.round(Date.now() / 1000);
  const paramsToSign = { folder, timestamp };
  const toSign =
    Object.keys(paramsToSign)
      .sort()
      .map((k) => `${k}=${paramsToSign[k]}`)
      .join("&") + apiSecret;
  const signature = crypto.createHash("sha1").update(toSign).digest("hex");

  return {
    cloudName,
    apiKey,
    timestamp,
    signature,
    folder,
  };
});
