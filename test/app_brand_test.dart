import 'package:flutter_test/flutter_test.dart';
import 'package:barrr/core/app_brand.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppBrand falls back when brand.env is not loaded', () {
    expect(AppBrand.appName, isNotEmpty);
    expect(AppBrand.logoAsset, 'assets/branding/logo.png');
    expect(AppBrand.supportPhone, isNotEmpty);
  });

  test('AppBrand.load reads brand.env asset', () async {
    await AppBrand.load();
    expect(AppBrand.appName, 'البطريق');
    expect(AppBrand.logoAsset, contains('branding'));
    expect(AppBrand.tagline, isNotEmpty);
  });
}
