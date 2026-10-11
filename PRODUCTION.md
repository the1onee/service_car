# إطلاق الإنتاج — البطريق

## عناوين الإنتاج

| الخدمة | العنوان |
|--------|---------|
| لوحة الأدمن | https://albatariq.com |
| API / FCM | https://albatariq.com/api/health |
| تطبيق Flutter (release) | `ApiConfig` → `https://albatariq.com` تلقائياً |

## الهوية (شعار / اسم)

عدّل `assets/branding/brand.env` وضع `assets/branding/logo.png` ثم أعد بناء التطبيق. التفاصيل في [GUIDE.md](./GUIDE.md).

## Android signing

1. الملفات المحلية (لا تُرفع إلى Git):
   - `android/upload-keystore.pfx`
   - `android/key.properties`
   - `android/RELEASE_SHA1.txt` (بصمات للمرجع)
2. أُضيفت بصمات الرفع إلى Firebase (`apps:android:sha:create`).
3. البناء:

```powershell
powershell -File scripts/build-release-apk.ps1
```

## نشر القواعد

```bash
cd barrr
npx firebase-tools deploy --only firestore:rules,firestore:indexes --project car-services-iraq
```

صلاحيات الأدمن المحدود تُفرض الآن في `firestore.rules` عبر `adminPermissions` (السوبر فقط على القاعدة العامة).

## نشر اللوحة + Express على VPS

```powershell
cd barrr-admin
npm run build
$env:VPS_PASSWORD='...'
node scripts/vps-deploy.mjs deploy
```

HTTPS/الدومين: `deploy/HTTPS.md` — `albatariq.com` → `31.220.90.124`.

## دخان

```powershell
powershell -File scripts/smoke-job-wallet-logic.ps1
powershell -File scripts/smoke-production.ps1
cd ../barrr-admin
npm run verify:prod
```

اختبار يدوي على جهاز (مرة واحدة قبل الإطلاق العام):

1. عميل: تسجيل → طلب سطحة/فني
2. مزوّد: استلام عرض + إشعار FCM
3. قبول → enRoute → إكمال → خصم عمولة
4. أدمن على https://albatariq.com: رؤية الطلب + اعتماد شحن محفظة

## أمان التشغيل

- لا ترفع `serviceAccount.json` / `adc.json` / `.env` / `key.properties` / `*.pfx`
- إن ظهرت كلمة مرور VPS في سجل محادثة سابقاً: **غيّرها من لوحة Contabo** فوراً
- على VPS يُفضَّل `serviceAccount.json` (موجود الآن) بدل الاعتماد على `adc.json` وحده
