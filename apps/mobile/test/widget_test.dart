import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:help/core/design_system/theme/app_theme.dart';
import 'package:help/features/home/domain/entities/home_content.dart';
import 'package:help/features/home/presentation/controllers/home_controller.dart';
import 'package:help/features/home/presentation/pages/home_page.dart';
import 'package:help/features/home/presentation/providers/home_providers.dart';

import 'features/home/fixtures/home_content_fixture.dart';

class _FixtureHomeController extends HomeController {
  @override
  Future<HomeContent> build() async => HomeContentFixture.content;
}

void main() {
  testWidgets('home renders its main discovery sections', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeControllerProvider.overrideWith(_FixtureHomeController.new),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const HomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Serviços populares'), findsOneWidget);
    expect(find.text('A gente resolve rápido.'), findsOneWidget);
    expect(find.text('Início'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Recomendados para você'), findsOneWidget);
  });
}
