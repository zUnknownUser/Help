import 'package:flutter_test/flutter_test.dart';
import 'package:help/core/result/result.dart';

void main() {
  group('Result', () {
    test('Success executa apenas onSuccess', () {
      const result = Success<int, String>(42);

      final value = result.fold(
        onSuccess: (data) => 'valor: $data',
        onFailure: (failure) => 'erro: $failure',
      );

      expect(value, 'valor: 42');
      expect(result.isSuccess, isTrue);
    });

    test('FailureResult executa apenas onFailure', () {
      const result = FailureResult<int, String>('falhou');

      final value = result.fold(
        onSuccess: (data) => 'valor: $data',
        onFailure: (failure) => 'erro: $failure',
      );

      expect(value, 'erro: falhou');
      expect(result.isSuccess, isFalse);
    });
  });
}
