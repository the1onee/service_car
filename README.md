# طلب الفني (Flutter + Firebase)

تطبيق واحد بثلاثة أدوار: **عميل** و**فني** و**إدارة**. النطاق الافتراضي على الخريطة: **مركز البصرة**.

المطابقة هجينة:
- **طوارئ** (سطحة، فتح سيارة، وقود): أقرب فنيّين لكل جولة، 30 ثانية، أول قبول يفوز.
- **صيانة/غسيل**: نافذة نحو دقيقتين ونصف لعدة فنيين. إن وصل عرض واحد يُعيَّن تلقائياً، وإن وصل أكثر يقارن العميل السعر والتقييم والمسافة.

الدفع نقداً بين العميل والفني. عمولة التطبيق 10% تُخصم من **محفظة الفني**. بدون توثيق أو رصيد أقل من 10,000 د.ع لا تُستقبل طلبات جديدة.

## التشغيل على المتصفح

```bash
flutter pub get
flutter run -d chrome --web-port 8080
```

ضع مفتاح Google Maps في `web/index.html` داخل سكربت Maps.
أنشئ مشروع Firebase وشغّل `flutterfire configure` حتى تعمل المصادقة والطلبات.

## التشغيل على الهاتف

1. `flutter create . --org com.barrr --project-name barrr --platforms android,ios`
2. ثبّت مفتاح الخرائط وصلاحيات الموقع كما في `docs/maps-and-permissions.md`
3. `firebase deploy --only firestore:rules,firestore:indexes,functions`
4. `flutter run`
