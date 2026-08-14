import 'package:flutter_test/flutter_test.dart';
import 'package:help/core/config/api_base_url.dart';

void main() {
  group('ApiBaseUrl', () {
    test('normaliza a URL configurada', () {
      expect(
        ApiBaseUrl.resolve(
          configuredUrl: ' https://api.vendlydigital.com.br/ ',
          isRelease: true,
          isAndroid: true,
        ),
        'https://api.vendlydigital.com.br',
      );
    });

    test('usa endereços locais corretos por plataforma em debug', () {
      expect(
        ApiBaseUrl.resolve(
          configuredUrl: '',
          isRelease: false,
          isAndroid: true,
        ),
        'http://10.0.2.2:8080',
      );
      expect(
        ApiBaseUrl.resolve(
          configuredUrl: '',
          isRelease: false,
          isAndroid: false,
        ),
        'http://127.0.0.1:8080',
      );
    });

    test('exige URL HTTPS explícita em release', () {
      expect(
        () => ApiBaseUrl.resolve(
          configuredUrl: '',
          isRelease: true,
          isAndroid: true,
        ),
        throwsStateError,
      );
      expect(
        () => ApiBaseUrl.resolve(
          configuredUrl: 'http://api.example.com',
          isRelease: true,
          isAndroid: true,
        ),
        throwsArgumentError,
      );
    });

    test('rejeita URL sem host ou com query', () {
      for (final value in ['api.example.com', 'https://api.example.com?x=1']) {
        expect(
          () => ApiBaseUrl.resolve(
            configuredUrl: value,
            isRelease: false,
            isAndroid: false,
          ),
          throwsArgumentError,
        );
      }
    });
  });

  test('permite HTTP em release somente quando autorizado explicitamente', () {
    expect(
      ApiBaseUrl.resolve(
        configuredUrl: 'http://192.168.0.10:8080',
        isRelease: true,
        isAndroid: true,
        allowInsecureHttp: true,
      ),
      'http://192.168.0.10:8080',
    );
  });
}
