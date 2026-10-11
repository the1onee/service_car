# دليل البطريق — تطبيق Flutter

مرجع مختصر للمطور ولمن يبني iOS/Android. للتفاصيل التشغيلية انظر [PRODUCTION.md](./PRODUCTION.md).

## ماذا يفعل التطبيق؟

منصة خدمات سيارات (البصرة افتراضياً): عميل يطلب → مزوّد (فني/ورشة/زيوت/دهان) يعرض أو يقبل → نقداً بينهما، وعمولة من محفظة المزوّد.

| الطبقة | التقنية |
|--------|---------|
| التطبيق | Flutter (`lib/`) |
| البيانات | Firebase Auth + Firestore (مشروع `car-services-iraq`) |
| الإشعارات | Express على VPS → FCM (`../barrr-admin/server`) |
| الأدمن | React على https://albatariq.com |

## هيكل مهم

```
barrr/
├── lib/
│   ├── main.dart              # إقلاع + تحميل الهوية
│   ├── core/
│   │   ├── app_brand.dart     # يقرأ brand.env
│   │   ├── api_config.dart    # عنوان API (إنتاج: albatariq.com)
│   │   ├── theme.dart         # ألوان وgradients
│   │   └── strings.dart       # نصوص الواجهة
│   ├── features/              # شاشات حسب الدور
│   ├── services/              # Auth, FCM, Jobs, …
│   └── legal/                 # شروط الاستخدام
├── assets/branding/
│   ├── brand.env              # الاسم، الشعار، الدعم ← عدّل هنا
│   ├── brand.env.example
│   └── logo.png               # ضع شعارك هنا (512×512 PNG)
├── android/                   # توقيع الإصدار: key.properties (محلي فقط)
├── firestore.rules            # أمان قاعدة البيانات
└── scripts/                   # بناء APK + دخان إنتاج
```

لوحة التحكم منفصلة: `../barrr-admin` — انظر [GUIDE هناك](../barrr-admin/GUIDE.md).

## تغيير الشعار والاسم (بدون لمس Dart)

1. ضع الصورة: `assets/branding/logo.png`
2. عدّل `assets/branding/brand.env`:

```env
APP_NAME=البطريق
TAGLINE=...
LOGO_ASSET=assets/branding/logo.png
SUPPORT_PHONE=0770...
SUPPORT_EMAIL=...
ABOUT_BLURB=...
```

3. أعد التشغيل/البناء: `flutter run` أو `powershell -File scripts/build-release-apk.ps1`

أيقونة الشاشة الرئيسية (launcher) لا تتغير من `brand.env` وحدها — بعد اعتماد اللوغو استخدم `flutter_launcher_icons` أو استبدال الأيقونات يدوياً في `android/` و`ios/`.

## تعديلات شائعة أخرى

| ماذا؟ | أين؟ |
|-------|------|
| ألوان الواجهة | `lib/core/theme.dart` |
| نصوص أزرار/شاشات | `lib/core/strings.dart` |
| شروط الاستخدام | `lib/legal/terms_of_use.dart` (ارفع `version` عند تغيير جوهري) |
| عنوان API | `lib/core/api_config.dart` أو `--dart-define=BARRR_API_BASE=...` |
| قواعد Firestore | `firestore.rules` ثم `firebase deploy --only firestore:rules` |

## تشغيل وبناء

```bash
flutter pub get
flutter run -d android   # أو chrome
```

إصدار Android موقّع (يتطلب SDK + `android/key.properties` محلياً):

```powershell
powershell -File scripts/build-release-apk.ps1
```

iOS: افتح `ios/Runner.xcworkspace` على Mac، نفس مشروع Firebase، وملف `logo.png` / `brand.env` مشترك.

## أمان — لا ترفع إلى Git

- `android/key.properties`, `*.pfx`, `*.jks`
- أي `serviceAccount.json` / كلمات مرور VPS
- أسرار Cloudinary إن وُجدت كمفاتيح سرية (الـ unsigned preset عبر dart-define)

## حالة الإنتاج

- لوحة الأدمن + API: https://albatariq.com  
- التحقق: `cd ../barrr-admin && npm run verify:prod`
