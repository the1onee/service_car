import 'package:barrr/legal/customer_terms.dart';

/// توافق خلفي — الشروط العامة السابقة أصبحت شروط العميل.
class AppTerms {
  AppTerms._();

  static const version = CustomerTerms.version;

  static String get title => CustomerTerms.title;

  static String get body => CustomerTerms.body;
}
