# البطريق (Flutter + Firebase)

**دليل سريع:** [GUIDE.md](./GUIDE.md) — الشعار والهوية: `assets/branding/brand.env` + `logo.png`.  
**إنتاج:** [PRODUCTION.md](./PRODUCTION.md).

تطبيق واحد بثلاثة أدوار: **عميل** و**فني** و**إدارة**. النطاق الافتراضي على الخريطة: **مركز البصرة**.

المطابقة هجينة:
- **طوارئ** (فتح سيارة، وقود): أقرب فنيّين لكل جولة، 30 ثانية، أول قبول يفوز.
- **سطحة**: عروض بدون مهلة — العميل يختار السطحة ويقبل العرض.
- **صيانة/غسيل**: نافذة نحو دقيقتين ونصف لعدة فنيين. إن وصل عرض واحد يُعيَّن تلقائياً، وإن وصل أكثر يقارن العميل السعر والتقييم والمسافة.

الدفع نقداً بين العميل والفني. عمولة التطبيق 10% تُخصم من **محفظة الفني**. بدون توثيق أو رصيد أقل من 10,000 د.ع لا تُستقبل طلبات جديدة.

**بدون Cloud Functions / بدون Blaze:** التوزيع والإشعارات وإتمام الطلب عبر التطبيق + سيرفر Express في `../barrr-admin/server`.

## المصادقة

- تسجيل الدخول: رقم الهاتف أو بريد حقيقي + كلمة المرور (أو Google).
- إنشاء الحساب: الاسم، الهاتف/البريد، كلمة المرور، العنوان — يُفتح كـ **حساب عميل** فقط.
- Firebase لا يدعم كلمة مرور لمزوّد الهاتف، فيُربط كل رقم ببريد داخلي
  `<digits>@phone.barrr.app`.
- **نسيان كلمة المرور:** رابط استعادة عبر Firebase للإيميل الحقيقي فقط.
  حسابات الهاتف تُوجَّه للتواصل مع الدعم (`07739601771`) — لا واتساب OTP.
- فعّل مزوّد **Email/Password** وقالب **Password reset** في Firebase Authentication.

## التشغيل

```bash
flutter pub get
flutter run -d chrome --web-hostname localhost --web-port 8080 \
  --dart-define=CLOUDINARY_CLOUD_NAME=your_cloud \
  --dart-define=CLOUDINARY_UPLOAD_PRESET=barrr_unsigned \
  --dart-define=BARRR_API_BASE=http://127.0.0.1:8787
# أو
flutter run -d android \
  --dart-define=CLOUDINARY_CLOUD_NAME=your_cloud \
  --dart-define=CLOUDINARY_UPLOAD_PRESET=barrr_unsigned \
  --dart-define=BARRR_API_BASE=http://10.0.2.2:8787
```

### رفع الصور (Cloudinary)

رفع **unsigned** فقط. مرّر عبر `--dart-define`:
- `CLOUDINARY_CLOUD_NAME`
- `CLOUDINARY_UPLOAD_PRESET` (مثل `barrr_unsigned`)

لا تضع أسراراً في المصدر.

### الخرائط

الخرائط عبر **OpenStreetMap** (مجانية، بلا مفتاح API):
- التطبيق: `flutter_map`
- لوحة الأدمن: Leaflet / `react-leaflet`

### نشر قواعد Firestore

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

### سيرفر الإشعارات / الإدارة

انظر `../barrr-admin/server/README.md` — FCM وwatchers وعمليات الأدمن عبر Admin SDK على VPS.

### بناء Android للإصدار (Release)

1. أنشئ مفتاح الرفع (مرة واحدة، احفظه بأمان):

الملفات المحلية `android/upload-keystore.pfx` + `android/key.properties` جاهزة (لا تُرفع إلى Git).
انظر `android/RELEASE_SHA1.txt` و`PRODUCTION.md`.

```powershell
powershell -File scripts/build-release-apk.ps1
```

في **release** يتصل التطبيق بـ `https://albatariq.com` تلقائياً.

بصمات SHA لمفتاح الرفع تُضاف عبر:
`npx firebase-tools apps:android:sha:create <appId> <hash>`

لوحة الأدمن: https://albatariq.com — انظر `../barrr-admin/deploy/HTTPS.md` و`PRODUCTION.md`.

## لوحة التحكم (ويب)

مشروع منفصل في `../barrr-admin` (Vite + React + TypeScript) على نفس مشروع Firebase.
الصلاحيات: السوبر أدمن كامل؛ الأدمن المحدود عبر `adminPermissions` في القواعد والواجهة.
كتالوج `services` يقرأه التطبيق ويُدار من اللوحة.
