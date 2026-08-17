import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:help/core/design_system/theme/app_theme.dart';
import 'package:help/features/home/presentation/widgets/home_content_view.dart';
import 'package:help/features/chat/presentation/providers/chat_providers.dart';
import 'package:help/features/main_navigation/presentation/main_shell.dart';

import 'features/home/fixtures/home_content_fixture.dart';

void main() {
  testWidgets('home visual snapshot at mobile size', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          unreadChatCountProvider.overrideWith((ref) => Stream.value(0)),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: MainShell(
            homeBuilder: (_) =>
                const HomeContentView(content: HomeContentFixture.content),
            requestsPage: const SizedBox(),
            conversationsPage: const SizedBox(),
            accountPage: const SizedBox(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/home_390x844.png'),
    );
  });
}
