class Cols {
  static const users = 'users';
  static const services = 'services';
  static const vehicleTypes = 'vehicleTypes';
  static const workshopSpecialties = 'workshopSpecialties';
  static const oilTypes = 'oilTypes';
  static const jobs = 'jobs';
  static const jobOffers = 'jobOffers';
  /// موقع دقيق منفصل عن مستند الطلب (يُكشف للفني بعد التعيين).
  static const jobLocations = 'jobLocations';
  static const appSettings = 'appSettings';
  static const cities = 'cities';
  static const serviceAreas = 'serviceAreas';
  static const walletEntries = 'walletEntries';
  static const walletTopUps = 'walletTopUps';
  static const notifications = 'notifications';
  static const supportTickets = 'supportTickets';
  /// مطالبات الضمان المرتبطة بطلب مكتمل (ليست طلبًا جديدًا).
  static const warrantyClaims = 'warrantyClaims';
  /// فهرس أرقام الهاتف: phoneRegistry/{9647…} → { uid }
  static const phoneRegistry = 'phoneRegistry';
  /// قفل زيارة المزوّد: providerSlots/{providerId} → { activeJobId }
  static const providerSlots = 'providerSlots';
}
