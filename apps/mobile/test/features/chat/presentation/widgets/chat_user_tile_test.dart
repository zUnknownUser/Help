import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/chat/domain/entities/chat_conversation.dart';
import 'package:help/features/chat/presentation/widgets/chat_user_tile.dart';

void main() {
  testWidgets('mostra contexto seguro e separa perfil de iniciar conversa', (
    tester,
  ) async {
    var opened = false;
    var viewed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatUserTile(
            user: const ChatUser(
              id: 'provider-1',
              displayName: 'Maria Silva',
              role: ChatUserRole.provider,
            ),
            onOpen: () => opened = true,
            onView: () => viewed = true,
          ),
        ),
      ),
    );

    expect(find.text('Profissional verificado'), findsOneWidget);
    await tester.tap(find.text('MS'));
    expect(viewed, isTrue);
    expect(opened, isFalse);

    await tester.tap(find.text('Maria Silva'));
    expect(opened, isTrue);
  });
}
