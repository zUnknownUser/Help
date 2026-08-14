import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:help/core/result/result.dart';
import 'package:help/features/home/domain/entities/home_content.dart';
import 'package:help/features/home/domain/failures/home_failure.dart';
import 'package:help/features/home/domain/use_cases/get_home.dart';
import 'package:help/features/home/presentation/providers/home_providers.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetHome extends Mock implements GetHome {}

void main() {
  test('publica o conteúdo agregado retornado pelo caso de uso', () async {
    final useCase = _MockGetHome();
    when(useCase.call).thenAnswer(
      (_) async => const Success<HomeContent, HomeFailure>(HomeContent.empty()),
    );
    final container = ProviderContainer(
      overrides: [getHomeProvider.overrideWithValue(useCase)],
    );
    final subscription = container.listen(homeControllerProvider, (_, _) {});
    addTearDown(subscription.close);
    addTearDown(container.dispose);

    final content = await container.read(homeControllerProvider.future);

    expect(content, const HomeContent.empty());
    verify(useCase.call).called(1);
  });

  test('publica erro e permite tentar novamente', () async {
    final useCase = _MockGetHome();
    var calls = 0;
    when(useCase.call).thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        return const FailureResult<HomeContent, HomeFailure>(
          HomeFailure(HomeFailureType.network),
        );
      }
      return const Success<HomeContent, HomeFailure>(HomeContent.empty());
    });
    final container = ProviderContainer(
      overrides: [getHomeProvider.overrideWithValue(useCase)],
    );
    final subscription = container.listen(homeControllerProvider, (_, _) {});
    addTearDown(subscription.close);
    addTearDown(container.dispose);

    await expectLater(
      container.read(homeControllerProvider.future),
      throwsA(isA<Exception>()),
    );
    await container.read(homeControllerProvider.notifier).retry();

    expect(container.read(homeControllerProvider).hasValue, isTrue);
    expect(calls, 2);
  });
}
