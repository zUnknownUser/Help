import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:help/core/design_system/theme/app_theme.dart';
import 'package:help/features/home/domain/entities/home_content.dart';
import 'package:help/features/home/domain/failures/home_failure.dart';
import 'package:help/features/home/presentation/controllers/home_controller.dart';
import 'package:help/features/home/presentation/pages/home_page.dart';
import 'package:help/features/home/presentation/providers/home_providers.dart';
import 'package:help/features/chat/presentation/providers/chat_providers.dart';
import 'package:help/features/main_navigation/presentation/main_shell.dart';

class _LoadingHomeController extends HomeController {
  @override
  Future<HomeContent> build() => Completer<HomeContent>().future;
}

class _ErrorHomeController extends HomeController {
  @override
  Future<HomeContent> build() async {
    throw const HomePresentationException(HomeFailure(HomeFailureType.network));
  }
}

void main() {
  testWidgets('mantém o esqueleto estrutural durante o carregamento', (
    tester,
  ) async {
    await _pump(tester, _LoadingHomeController.new);

    expect(find.byKey(const Key('home_loading')), findsOneWidget);
    expect(find.text('Início'), findsOneWidget);
  });

  testWidgets('oferece retry quando não há rede nem cache', (tester) async {
    await _pump(tester, _ErrorHomeController.new);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.byKey(const Key('home_error')), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });
}

Future<void> _pump(WidgetTester tester, HomeController Function() controller) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        homeControllerProvider.overrideWith(controller),
        unreadChatCountProvider.overrideWith((ref) => Stream.value(0)),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: MainShell(
          homeBuilder: (_) => const HomePage(),
          requestsPage: const SizedBox(),
          conversationsPage: const SizedBox(),
          accountPage: const SizedBox(),
        ),
      ),
    ),
  );
}
