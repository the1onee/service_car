class AppStrings {
  static const appName = 'طلب الفني';
  static const tagline = 'فني موثوق يصل إليك في أي مكان';

  // المصادقة
  static const login = 'تسجيل الدخول';
  static const register = 'إنشاء حساب';
  static const password = 'كلمة المرور';
  static const confirmPassword = 'تأكيد كلمة المرور';
  static const newPassword = 'كلمة المرور الجديدة';
  static const name = 'الاسم الكامل';
  static const phone = 'رقم الهاتف';
  static const address = 'العنوان';
  static const welcomeBack = 'أهلاً بعودتك';
  static const loginHint = 'سجّل عبر Google أو بالهاتف/البريد وكلمة المرور';
  static const registerTitle = 'إنشاء حساب';
  static const registerHint = 'Google أو رقم الهاتف/البريد مع كلمة المرور';
  static const continueWithGoogle = 'Google';
  static const phoneOrEmail = 'رقم الهاتف أو البريد الإلكتروني';
  static const phoneOrEmailHint = '0770… أو name@email.com';
  static const addPhoneTitle = 'أضف رقم هاتفك';
  static const addPhoneHint =
      'لإكمال حسابك نحتاج رقم هاتف عراقي صالح للتواصل.';
  static const savePhone = 'حفظ الرقم والمتابعة';
  static const customerAccountNote =
      'حساب العميل جاهز فوراً بعد التسجيل.';
  static const technicianAccountNote =
      'حساب الفني يُرسل لطلب انضمام، ويُفعَّل بعد موافقة الإدارة.';
  static const workshopAccountNote =
      'حساب الورشة يُرسل للمراجعة، ويُفعَّل بعد موافقة الإدارة لاستقبال طلبات القطع.';
  static const oilWorkshopAccountNote =
      'حساب ورشة الزيوت يُرسل للمراجعة، ويُفعَّل بعد موافقة الإدارة لاستقبال طلبات تبديل الزيت في البيت.';
  static const paintShopAccountNote =
      'حساب ورشة الدهان يُرسل للمراجعة، ويُفعَّل بعد موافقة الإدارة لاستقبال طلبات الدهان.';
  static const idCard = 'رقم البطاقة';
  static const skills = 'المهارات / الخدمات';
  static const vehicleTypes = 'أنواع السيارات';
  static const workshopName = 'اسم الورشة';
  static const workshopSpecialty = 'اختصاص الورشة';
  static const workshopOps = 'العمليات المهمة';
  static const city = 'المدينة';
  static const selectCity = 'اختر المدينة';
  static const selectSpecialty = 'اختر الاختصاص';
  static const oilWorkshopTier = 'تصنيف الورشة';
  static const oilWorkshopAgency = 'وكالة أصلية';
  static const oilWorkshopTrusted = 'موثوقة';
  static const optional = 'اختياري';
  static const forgotPassword = 'نسيت كلمة المرور؟';
  static const resetPassword = 'استعادة كلمة المرور';
  static const resetPasswordEmailHint =
      'أدخل بريدك الإلكتروني وسنرسل رابطاً لتعيين كلمة مرور جديدة.';
  static const sendResetLink = 'إرسال رابط الاستعادة';
  static const resetEmailSentTitle = 'تحقق من بريدك';
  static const resetEmailSentBody =
      'إن وُجد حساب بهذا البريد فستصلك رسالة تحتوي رابط استعادة كلمة المرور.';
  static const phoneResetBlockedTitle = 'تواصل مع الدعم';
  static const phoneResetBlockedBody =
      'الحسابات المسجّلة برقم الهاتف لا يمكن استعادة كلمة مرورها من التطبيق. تواصل مع الدعم لإجراء التعديل.';
  static const supportPhone = '07739601771';
  static const callSupport = 'اتصال بالدعم';
  static const noAccount = 'ليس لديك حساب؟';
  static const haveAccount = 'لديك حساب بالفعل؟';
  static const continueLabel = 'متابعة';
  static const logout = 'تسجيل الخروج';

  // الأدوار
  static const customer = 'عميل';
  static const technician = 'فني';
  static const workshop = 'ورشة قطع';
  static const oilWorkshop = 'ورشة زيوت';
  static const paintShop = 'ورشة دهان';

  // الرحلة
  static const pickLocation = 'حدد موقعك على الخريطة';
  static const confirmLocation = 'تأكيد الموقع';
  static const outsideCoverage = 'الموقع خارج نطاق التغطية الحالي. حرّك الدبوس داخل الدائرة.';
  static String coverageLabel(String city) => 'التغطية: $city';
  static const pickAddressOnMap = 'تحديد العنوان على الخريطة';
  static const addressFromMap = 'تم تحديد الموقع على الخريطة';
  static const pickService = 'اختر الخدمة';
  static const pickVehicleType = 'حدد نوع السيارة';
  static const selectVehicleTypeRequired = 'اختر نوع السيارة قبل إرسال الطلب.';
  static const pickLocationOnMap = 'تحديد الموقع على الخريطة';
  static const locationLockedDuringJob = 'الموقع مقفل أثناء الطلب الحالي';
  static const locationPermissionDenied =
      'تعذّر الوصول للموقع. يمكنك تحديده يدوياً على الخريطة.';
  static const locationPermissionDeniedForever =
      'صلاحية الموقع مرفوضة. افتح الإعدادات لتفعيلها، أو حدد الموقع يدوياً.';
  static const openSettings = 'فتح الإعدادات';
  static const searching = 'جاري البحث عن فني مناسب...';
  static const collectingQuotes = 'ننتظر عروضاً من فنيين قريبين...';
  static const compareQuotes = 'قارن العروض واختر الفني';
  static const verifiedBadge = 'فني موثق';
  static const wallet = 'المحفظة';
  static const walletHistory = 'سجل المحفظة';
  static const walletAdminNote = 'الشحن يتم من الإدارة. لا يمكن شحن الرصيد من التطبيق.';
  static const cashNote =
      'الدفع نقداً للفني مباشرة. التطبيق يخصم عمولة الخدمة من محفظة الفني.';
  static const accept = 'قبول';
  static const reject = 'رفض';
  static const cancelJob = 'إلغاء الطلب';
  static const withdrawSearch = 'إلغاء والبحث عن فني';
  static const online = 'متاح لاستقبال الطلبات';
  static const offline = 'غير متاح';
  static const pendingVerify = 'حسابك بانتظار توثيق الإدارة';
  static const initialPrice = 'السعر المبدئي';
  static const finalPrice = 'السعر النهائي';
  static const receivedAmount = 'المبلغ المستلم';
  static const jobCreatedDispatchFailed =
      'تم إنشاء الطلب وتعذر بدء المطابقة. تابع من الطلبات.';
  static const arrived = 'وصلت إلى الموقع';
  static const startWork = 'بدء العمل';
  static const endJob = 'إنهاء المهمة';
  static const warranty = 'ضمان يومين';
  static const warrantyPart = 'على القطعة';
  static const warrantyWork = 'على العملية';
  static const rate = 'تقييم';
  static const myServices = 'خدماتي';
}
