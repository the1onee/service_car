class DemoMode {
  static const enabled = true;
}

class DemoAccounts {
  static const password = '12345678';

  static const customerEmail = 'customer@barrr.test';
  static const techEmail = 'tech@barrr.test';
  static const tech2Email = 'tech2@barrr.test';
  static const adminEmail = 'admin@barrr.test';

  static const all = <({String label, String email, String name})>[
    (label: 'عميل', email: customerEmail, name: 'علي البصري'),
    (label: 'فني موثق', email: techEmail, name: 'حسين الميكانيكي'),
    (label: 'فني موثق ٢', email: tech2Email, name: 'محمد الإطارات'),
    (label: 'إدارة', email: adminEmail, name: 'إدارة التطبيق'),
  ];
}
