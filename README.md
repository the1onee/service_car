# البطريق (Flutter + Firebase)

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

```bash
keytool -genkey -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias barrr
```

2. انسخ `android/key.properties.example` إلى `android/key.properties` واملأ كلمات المرور والمسار.
3. ابنِ:

```bash
flutter build apk --release
# أو مع عنوان API إن لزم بعد الدومين:
# flutter build apk --release --dart-define=BARRR_API_BASE=https://your-domain.com
```

4. أضف **SHA-1** لمفتاح الرفع في Firebase Console → Project settings → Your apps (Android)، وإلا قد يفشل Google Sign-In في الإصدار.

HTTPS على لوحة الأدمن: انظر `../barrr-admin/deploy/HTTPS.md` (يتطلب دومين).

## لوحة التحكم (ويب)

مشروع منفصل في `../barrr-admin` (Vite + React + TypeScript) على نفس مشروع Firebase.
الصلاحيات: القاعدة العامة في `firestore.rules` تمنح الأدمن قراءة وكتابة وحذفاً على كل
المجموعات، وكتالوج `services` للأدمن فقط بينما يقرأه التطبيق.
