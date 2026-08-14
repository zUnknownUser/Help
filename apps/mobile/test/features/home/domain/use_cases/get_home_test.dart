import 'package:flutter_test/flutter_test.dart';
import 'package:help/core/result/result.dart';
import 'package:help/features/home/domain/entities/home_content.dart';
import 'package:help/features/home/domain/failures/home_failure.dart';
import 'package:help/features/home/domain/repositories/home_repository.dart';
import 'package:help/features/home/domain/use_cases/get_home.dart';
import 'package:mocktail/mocktail.dart';

class _MockHomeRepository extends Mock implements HomeRepository {}

void main() {
  test('delega a composição da Home ao repositório', () async {
    final repository = _MockHomeRepository();
    when(repository.getHome).thenAnswer(
      (_) async => const Success<HomeContent, HomeFailure>(HomeContent.empty()),
    );
    final useCase = GetHome(repository);

    final result = await useCase();

    expect(result.isSuccess, isTrue);
    verify(repository.getHome).called(1);
  });
}
