import 'package:barrr/models/service_item.dart';

/// كتالوج إطلاق البصرة فقط — طوارئ مقابل خدمات يقارن العميل أسعارها.
const seedServices = <ServiceItem>[
  ServiceItem(
    id: 'oil',
    titleAr: 'زيوت وفلاتر',
    category: 'صيانة',
  ),
  ServiceItem(
    id: 'battery',
    titleAr: 'بطارية: اشتراك وشحن وتبديل',
    category: 'كهرباء',
  ),
  ServiceItem(
    id: 'tires',
    titleAr: 'إطارات: نفخ وترقيع وتبديل',
    category: 'إطارات',
  ),
  ServiceItem(
    id: 'wash',
    titleAr: 'غسيل وتلميع متنقل',
    category: 'عناية',
  ),
  ServiceItem(
    id: 'brakes',
    titleAr: 'تبديل الفحمات',
    category: 'صيانة سريعة',
  ),
  ServiceItem(
    id: 'spark',
    titleAr: 'تبديل البواجي',
    category: 'صيانة سريعة',
  ),
  ServiceItem(
    id: 'ac',
    titleAr: 'شحن فريون المكيف',
    category: 'صيانة سريعة',
  ),
  ServiceItem(
    id: 'towing',
    titleAr: 'سطحة ومساعدة على الطريق',
    category: 'طوارئ',
    isEmergency: true,
  ),
  ServiceItem(
    id: 'locks',
    titleAr: 'فتح السيارات المغلقة',
    category: 'طوارئ',
    isEmergency: true,
  ),
  ServiceItem(
    id: 'fuel',
    titleAr: 'تزويد بالوقود',
    category: 'طوارئ',
    isEmergency: true,
  ),
];

const emergencyServiceIds = {'towing', 'locks', 'fuel'};

bool isEmergencyService(String serviceId) => emergencyServiceIds.contains(serviceId);
