import 'package:barrr/legal/customer_terms.dart';
import 'package:barrr/legal/technician_terms.dart';
import 'package:barrr/legal/workshop_terms.dart';
import 'package:barrr/models/app_user.dart';

/// اختيار شروط الاستخدام حسب دور الحساب.
class RoleTerms {
  RoleTerms._();

  static String versionFor(UserRole role) {
    switch (role) {
      case UserRole.technician:
        return TechnicianTerms.version;
      case UserRole.workshop:
      case UserRole.oilWorkshop:
      case UserRole.paintShop:
        return WorkshopTerms.version;
      case UserRole.customer:
      case UserRole.admin:
        return CustomerTerms.version;
    }
  }

  static String titleFor(UserRole role) {
    switch (role) {
      case UserRole.technician:
        return TechnicianTerms.title;
      case UserRole.workshop:
      case UserRole.oilWorkshop:
      case UserRole.paintShop:
        return WorkshopTerms.title;
      case UserRole.customer:
      case UserRole.admin:
        return CustomerTerms.title;
    }
  }

  static String bodyFor(UserRole role) {
    switch (role) {
      case UserRole.technician:
        return TechnicianTerms.body;
      case UserRole.workshop:
      case UserRole.oilWorkshop:
      case UserRole.paintShop:
        return WorkshopTerms.body;
      case UserRole.customer:
      case UserRole.admin:
        return CustomerTerms.body;
    }
  }
}
