import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/chat/presentation/providers/chat_providers.dart';
import 'package:help/features/main_navigation/presentation/main_shell.dart';
import 'package:help/features/main_navigation/presentation/main_shell_controller.dart';
import 'package:help/features/main_navigation/presentation/main_tab.dart';

void main() {
  testWidgets('troca abas por toque e gesto sem empilhar rotas', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = MainShellController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          unreadChatCountProvider.overrideWith((ref) => Stream.value(3)),
        ],
        child: MaterialApp(
          home: MainShell(
            controller: controller,
            homeBuilder: (_) => const _Page('home'),
            requestsPage: const _Page('requests'),
            conversationsPage: const _Page('conversations'),
            accountPage: const _Page('account'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('page_home')), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(find.text('3'), findsOneWidget);
    expect(_asset('assets/icons/conversations.png'), findsOneWidget);
    expect(_asset('assets/icons/profile.png'), findsOneWidget);

    controller.select(MainTab.requests);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('page_requests')), findsOneWidget);

    await tester.tap(find.byKey(const Key('main_tab_conversations')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('page_conversations')), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);

    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('page_account')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('page_home')), findsOneWidget);
  });
}

Finder _asset(String name) => find.byWidgetPredicate(
  (widget) =>
      widget is Image &&
      widget.image is AssetImage &&
      (widget.image as AssetImage).assetName == name,
);

class _Page extends StatelessWidget {
  const _Page(this.name);

  final String name;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: Key('page_$name'),
    body: Center(child: Text(name)),
  );
}
