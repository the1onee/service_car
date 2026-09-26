import 'package:barrr/models/service_item.dart';

/// كتالوج الإطلاق — يشمل صفحات التعريف الخمس الأساسية وخدمات الطوارئ.
const seedServices = <ServiceItem>[
  ServiceItem(
    id: 'technician',
    titleAr: 'فني سيارات',
    category: 'صيانة',
    providerKind: ServiceProviderKind.fieldTech,
    sortOrder: 0,
    descriptionAr:
        'نوفّر فني سيارات متخصصاً حسب نوع المشكلة، سواء كانت كهربائية أو ميكانيكية. '
        'يمكن تنفيذ الخدمة في موقع العميل عندما يكون العطل قابلاً للإصلاح ميدانياً، '
        'مع تشخيص واضح وخطة عمل قبل البدء.',
    highlightsAr: [
      'كهربائي سيارات: البطارية، التشغيل، الإنارة، الأسلاك، والفحص الكهربائي/الإلكتروني',
      'فيتر/ميكانيكي: الأعطال الميكانيكية وصيانة وإصلاح أجزاء السيارة',
      'الخدمة في موقعك عند إمكانية الإصلاح الميداني',
      'تحديد التخصص المناسب حسب وصف العطل',
    ],
  ),
  ServiceItem(
    id: 'oil',
    titleAr: 'خدمة الزيوت',
    category: 'صيانة',
    providerKind: ServiceProviderKind.mobile,
    sortOrder: 10,
    descriptionAr:
        'خدمة تبديل الزيوت والفلاتر في منزل العميل أو في موقعه، مع التركيز على '
        'اختيار الزيت المناسب لنوع السيارة والموديل، واستخدام زيوت أصلية أو من مصادر موثوقة، '
        'والتأكد من الكمية الصحيحة بعد التبديل.',
    highlightsAr: [
      'تبديل زيت المحرك',
      'تبديل زيت ناقل الحركة (الجير/القير)',
      'تبديل فلاتر الزيت والفلاتر المرتبطة بالخدمة',
      'اختيار نوع الزيت حسب الشركة والموديل',
      'تنفيذ الخدمة في موقع العميل',
    ],
  ),
  ServiceItem(
    id: 'wash',
    titleAr: 'غسيل السيارات',
    category: 'عناية',
    providerKind: ServiceProviderKind.mobile,
    sortOrder: 20,
    descriptionAr:
        'خدمة غسيل السيارات بأسعار مناسبة مع إمكانية التنفيذ في موقع العميل. '
        'مناسبة للاستخدام الدوري والمعتاد، وتشمل خيارات للعناية الخارجية والداخلية '
        'مع إمكانية إضافة التلميع والتنظيف التفصيلي.',
    highlightsAr: [
      'غسيل الهيكل الخارجي',
      'تنظيف المقصورة الداخلية',
      'تنظيف الأرضيات والمقاعد حسب نوع الباقة',
      'إمكانية التلميع والتنظيف التفصيلي',
      'الخدمة في موقع العميل',
    ],
  ),
  ServiceItem(
    id: 'parts',
    titleAr: 'قطع غيار السيارات',
    category: 'قطع غيار',
    providerKind: ServiceProviderKind.partsShop,
    sortOrder: 30,
    descriptionAr:
        'اطلب قطعة الغيار التي تحتاجها لسيارتك عبر التطبيق. يمكنك رفع صورة للقطعة '
        'وإضافة بيانات السيارة (الشركة والموديل والسنة) وكتابة اسم القطعة أو وصفها. '
        'تقوم الورش أو الجهات المورّدة بالبحث عن القطعة وتوضيح نوعها وحالتها وسعرها، '
        'مع إمكانية التركيب إذا كانت الجهة تقدّم هذه الخدمة.',
    highlightsAr: [
      'طلب قطعة مع صورة توضيحية',
      'إدخال شركة السيارة والموديل والسنة',
      'وصف القطعة أو اسمها إن كنت تعرفه',
      'توضيح النوع: أصلية أو تجارية أو مستعملة حسب المتوفر',
      'توضيح الحالة والسعر وإمكانية التركيب',
    ],
  ),
  ServiceItem(
    id: 'paint',
    titleAr: 'دهان السيارات',
    category: 'دهان',
    providerKind: ServiceProviderKind.paintShop,
    sortOrder: 40,
    descriptionAr:
        'خدمة دهان السيارات عبر ورش الدهان الرسمية المعتمدة. تشمل تقدير الضرر، '
        'دهان أجزاء محددة أو كامل الهيكل حسب الحاجة، واستخدام مواد مناسبة مع '
        'التنسيق على موعد الورشة — وليست خدمة متنقلة افتراضياً.',
    highlightsAr: [
      'تنفيذ عبر ورش الدهان الرسمية',
      'تقدير الضرر وخطة الإصلاح قبل البدء',
      'دهان جزئي أو كامل حسب الحالة',
      'مواد ودهانات مناسبة لنوع السيارة',
      'مواعيد وتنسيق مع الورشة',
    ],
  ),
  ServiceItem(
    id: 'battery',
    titleAr: 'بطارية: اشتراك وشحن وتبديل',
    category: 'كهرباء',
    providerKind: ServiceProviderKind.fieldTech,
    sortOrder: 50,
  ),
  ServiceItem(
    id: 'tires',
    titleAr: 'إطارات: نفخ وترقيع وتبديل',
    category: 'إطارات',
    providerKind: ServiceProviderKind.mobile,
    sortOrder: 60,
  ),
  ServiceItem(
    id: 'brakes',
    titleAr: 'تبديل الفحمات',
    category: 'صيانة سريعة',
    providerKind: ServiceProviderKind.fieldTech,
    sortOrder: 70,
  ),
  ServiceItem(
    id: 'spark',
    titleAr: 'تبديل البواجي',
    category: 'صيانة سريعة',
    providerKind: ServiceProviderKind.fieldTech,
    sortOrder: 80,
  ),
  ServiceItem(
    id: 'ac',
    titleAr: 'شحن فريون المكيف',
    category: 'صيانة سريعة',
    providerKind: ServiceProviderKind.fieldTech,
    sortOrder: 90,
  ),
  ServiceItem(
    id: 'towing',
    titleAr: 'سطحة ومساعدة على الطريق',
    category: 'طوارئ',
    isEmergency: true,
    providerKind: ServiceProviderKind.mobile,
    sortOrder: 100,
  ),
  ServiceItem(
    id: 'locks',
    titleAr: 'فتح السيارات المغلقة',
    category: 'طوارئ',
    isEmergency: true,
    providerKind: ServiceProviderKind.fieldTech,
    sortOrder: 110,
  ),
  ServiceItem(
    id: 'fuel',
    titleAr: 'تزويد بالوقود',
    category: 'طوارئ',
    isEmergency: true,
    providerKind: ServiceProviderKind.mobile,
    sortOrder: 120,
  ),
];

const emergencyServiceIds = {'towing', 'locks', 'fuel'};

bool isEmergencyService(String serviceId) => emergencyServiceIds.contains(serviceId);

/// خدمات تُستبعد من مسار «فني» (قطع / غسيل / زيوت / دهان).
const _excludedFromTechnician = {'parts', 'wash', 'oil', 'paint'};

/// معرفات صيانة ميدانية تُعرض مع بلاطة الفني.
const technicianFieldServiceIds = {
  'technician',
  'battery',
  'brakes',
  'spark',
  'ac',
};

/// يصفّي الكتالوج حسب نقطة الدخول من الهبوط.
///
/// - `technician`: خدمات فني ميداني فقط (بدون قطع/غسيل/زيوت/دهان/طوارئ).
/// - معرف خدمة محددة: تلك الخدمة وحدها.
/// - `null`: القائمة كما هي.
List<ServiceItem> filterServicesForEntry(
  String? entryId,
  List<ServiceItem> all,
) {
  if (entryId == null || entryId.isEmpty) return all;
  if (entryId == 'technician') {
    return all
        .where((s) {
          if (_excludedFromTechnician.contains(s.id)) return false;
          if (s.isEmergency) return false;
          if (s.providerKind == ServiceProviderKind.partsShop) return false;
          if (s.providerKind == ServiceProviderKind.paintShop) return false;
          return s.providerKind == ServiceProviderKind.fieldTech ||
              technicianFieldServiceIds.contains(s.id);
        })
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }
  return all.where((s) => s.id == entryId).toList();
}
