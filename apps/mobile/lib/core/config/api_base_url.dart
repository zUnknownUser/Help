abstract final class ApiBaseUrl {
  static String resolve({
    required String configuredUrl,
    required bool isRelease,
    required bool isAndroid,
  }) {
    final value = configuredUrl.trim();
    if (value.isEmpty) {
      if (isRelease) {
        throw StateError('API_BASE_URL is required in release builds.');
      }
      return isAndroid ? 'http://10.0.2.2:8080' : 'http://127.0.0.1:8080';
    }

    final uri = Uri.tryParse(value);
    final isHttp = uri?.scheme == 'http' || uri?.scheme == 'https';
    final isValid =
        uri != null &&
        isHttp &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment;
    if (!isValid) {
      throw ArgumentError.value(configuredUrl, 'API_BASE_URL', 'invalid URL');
    }
    if (isRelease && uri.scheme != 'https') {
      throw ArgumentError.value(
        configuredUrl,
        'API_BASE_URL',
        'release builds require HTTPS',
      );
    }
    return value.replaceFirst(RegExp(r'/+$'), '');
  }
}
