import 'package:flutter_test/flutter_test.dart';
import 'package:barrr/legal/customer_terms.dart';
import 'package:barrr/legal/role_terms.dart';
import 'package:barrr/legal/technician_terms.dart';
import 'package:barrr/legal/workshop_terms.dart';
import 'package:barrr/models/app_user.dart';

void main() {
  test('role terms map to the correct document version', () {
    expect(RoleTerms.versionFor(UserRole.customer), CustomerTerms.version);
    expect(RoleTerms.versionFor(UserRole.technician), TechnicianTerms.version);
    expect(RoleTerms.versionFor(UserRole.workshop), WorkshopTerms.version);
    expect(RoleTerms.versionFor(UserRole.oilWorkshop), WorkshopTerms.version);
    expect(RoleTerms.versionFor(UserRole.paintShop), WorkshopTerms.version);
  });

  test('titles and bodies are non-empty per role', () {
    for (final role in UserRole.values) {
      expect(RoleTerms.titleFor(role), isNotEmpty);
      expect(RoleTerms.bodyFor(role).trim(), isNotEmpty);
    }
  });

  test('customer terms reference the standalone privacy policy', () {
    expect(CustomerTerms.body, contains('سياسة الخصوصية'));
    expect(CustomerTerms.body, contains('albatariq.com/privacy.html'));
  });
}
