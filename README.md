# طلب الفني (Flutter + Firebase)

تطبيق واحد بثلاثة أدوار: **عميل** و**فني** و**إدارة**. النطاق الافتراضي على الخريطة: **مركز البصرة**.

المطابقة هجينة:
- **طوارئ** (سطحة، فتح سيارة، وقود): أقرب فنيّين لكل جولة، 30 ثانية، أول قبول يفوز.
- **صيانة/غسيل**: نافذة نحو دقيقتين ونصف لعدة فنيين. إن وصل عرض واحد يُعيَّن تلقائياً، وإن وصل أكثر يقارن العميل السعر والتقييم والمسافة.

الدفع نقداً بين العميل والفني. عمولة التطبيق 10% تُخصم من **محفظة الفني**. بدون توثيق أو رصيد أقل من 10,000 د.ع لا تُستقبل طلبات جديدة.

**بدون Cloud Functions / بدون Blaze:** التوزيع والإشعارات وإتمام الطلب عبر التطبيق + سيرفر Express في `../barrr-admin/server`.

## المصادقة

- تسجيل الدخول: رقم الهاتف + كلمة المرور.
- إنشاء الحساب: الاسم، الهاتف، كلمة المرور، العنوان — يُفتح كـ **حساب عميل** فقط.
- Firebase لا يدعم كلمة مرور لمزوّد الهاتف، فيُربط كل رقم ببريد داخلي
  `<digits>@phone.barrr.app`.
- فعّل مزوّد **Email/Password** في Firebase Authentication (والهاتف كمعرّف عبر البريد الداخلي).

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

## لوحة التحكم (ويب)

مشروع منفصل في `../barrr-admin` (Vite + React + TypeScript) على نفس مشروع Firebase.
الصلاحيات: القاعدة العامة في `firestore.rules` تمنح الأدمن قراءة وكتابة وحذفاً على كل
المجموعات، وكتالوج `services` للأدمن فقط بينما يقرأه التطبيق.
