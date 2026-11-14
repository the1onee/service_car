import 'package:flutter/foundation.dart';

enum AppEnvironment { production, staging }

class AppEnvironmentConfig {
  AppEnvironmentConfig._();

  static const _rawEnvironment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'production',
  );

  static AppEnvironment get current => switch (_rawEnvironment) {
        'production' => AppEnvironment.production,
        'staging' => AppEnvironment.staging,
        _ => throw StateError(
            'Unsupported APP_ENV="$_rawEnvironment". Use production or staging.',
          ),
      };

  static bool get isStaging => current == AppEnvironment.staging;

  static String get expectedFirebaseProjectId =>
      isStaging ? 'car-services-iraq-staging' : 'car-services-iraq';

  static void validateApiBase(String apiBase) {
    final uri = Uri.tryParse(apiBase);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw StateError('BARRR_API_BASE must be an absolute URL.');
    }
    if (isStaging &&
        (uri.host == 'albatariq.com' || uri.host == 'www.albatariq.com')) {
      throw StateError('Staging must never use the production API.');
    }
    if (!isStaging && kReleaseMode && uri.scheme != 'https') {
      throw StateError('Production release builds require an HTTPS API.');
    }
  }

  static void validateFirebaseProject(String projectId) {
    if (projectId != expectedFirebaseProjectId) {
      throw StateError(
        'APP_ENV=$_rawEnvironment expected Firebase project '
        '$expectedFirebaseProjectId, but received $projectId.',
      );
    }
  }
}
