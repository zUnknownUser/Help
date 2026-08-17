import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:help/core/design_system/theme/app_theme.dart';
import 'package:help/core/result/result.dart';
import 'package:help/features/scheduling/data/scheduling_providers.dart';
import 'package:help/features/scheduling/domain/entities/provider_schedule.dart';
import 'package:help/features/scheduling/domain/repositories/scheduling_repository.dart';
import 'package:help/features/scheduling/presentation/pages/provider_schedule_page.dart';

void main() {
  testWidgets('edita um dia por vez e mantém a ação principal acessível', (
    tester,
  ) async {
    final repository = _ScheduleRepository();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [schedulingRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const ProviderSchedulePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sua semana'), findsOneWidget);
    expect(find.byKey(const Key('schedule_weekday_0')), findsOneWidget);
    expect(find.byKey(const Key('schedule_weekday_6')), findsOneWidget);
    expect(find.text('Salvar alterações'), findsOneWidget);

    await tester.tap(find.byKey(const Key('schedule_weekday_1')));
    await tester.pumpAndSettle();

    expect(find.text('Segunda-feira'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('18:00'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../../goldens/provider_schedule_390x844.png'),
    );

    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();

    expect(repository.saveCalls, 1);
    expect(find.text('Agenda atualizada.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _ScheduleRepository implements SchedulingRepository {
  int saveCalls = 0;

  final schedule = const ProviderSchedule(
    timeZone: 'America/Manaus',
    minimumNoticeMinutes: 60,
    bookingHorizonDays: 60,
    bufferMinutes: 15,
    slotIntervalMinutes: 30,
    version: 1,
    rules: [
      AvailabilityRule(weekday: 1, startMinute: 480, endMinute: 1080),
      AvailabilityRule(weekday: 2, startMinute: 480, endMinute: 1080),
      AvailabilityRule(weekday: 3, startMinute: 480, endMinute: 1080),
      AvailabilityRule(weekday: 4, startMinute: 480, endMinute: 1080),
      AvailabilityRule(weekday: 5, startMinute: 480, endMinute: 1020),
    ],
    blocks: [],
  );

  @override
  Future<SchedulingResult<ProviderSchedule>> getProviderSchedule() async =>
      Success(schedule);

  @override
  Future<SchedulingResult<ProviderSchedule>> saveProviderSchedule(
    ProviderSchedule schedule,
  ) async {
    saveCalls++;
    return Success(schedule);
  }

  @override
  Future<SchedulingResult<ScheduleBlock>> addBlock(ScheduleBlockDraft draft) =>
      throw UnimplementedError();

  @override
  Future<SchedulingResult<void>> deleteBlock(String id) =>
      throw UnimplementedError();

  @override
  Future<SchedulingResult<AvailableSlotPage>> getAvailableSlots(
    String serviceId, {
    String? cursor,
    int limit = 40,
  }) => throw UnimplementedError();
}
