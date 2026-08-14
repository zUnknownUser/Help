import 'package:flutter/foundation.dart';

import 'api_base_url.dart';

abstract final class AppConfig {
  static const _configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const _allowInsecureHttp = bool.fromEnvironment('ALLOW_INSECURE_HTTP');

  static final apiBaseUrl = ApiBaseUrl.resolve(
    configuredUrl: _configuredApiBaseUrl,
    isRelease: kReleaseMode,
    isAndroid: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
    allowInsecureHttp: _allowInsecureHttp,
  );
}
