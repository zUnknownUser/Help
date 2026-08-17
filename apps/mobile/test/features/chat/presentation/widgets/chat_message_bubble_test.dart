import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/chat/domain/entities/chat_message.dart';
import 'package:help/features/chat/presentation/widgets/chat_message_bubble.dart';

void main() {
  testWidgets('shows edited marker and exposes author action', (tester) async {
    var actions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageBubble(
            message: _message(editedAt: DateTime(2026, 8, 16, 12)),
            mine: true,
            onLongPress: () => actions++,
          ),
        ),
      ),
    );

    expect(find.text('editada'), findsOneWidget);
    await tester.longPress(find.text('conteúdo privado'));
    expect(actions, 1);
  });

  testWidgets('replaces deleted content with a tombstone', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageBubble(
            message: _message(deletedAt: DateTime(2026, 8, 16, 12)),
            mine: false,
          ),
        ),
      ),
    );

    expect(find.text('Mensagem apagada'), findsOneWidget);
    expect(find.text('conteúdo privado'), findsNothing);
  });
}

ChatMessage _message({DateTime? editedAt, DateTime? deletedAt}) => ChatMessage(
  clientId: 'client-id',
  serverId: 'server-id',
  conversationId: 'conversation-id',
  senderId: 'me',
  content: deletedAt == null ? 'conteúdo privado' : '',
  localCreatedAt: DateTime(2026, 8, 16, 11),
  serverCreatedAt: DateTime(2026, 8, 16, 11),
  sequence: 1,
  editedAt: editedAt,
  deletedAt: deletedAt,
  version: editedAt == null && deletedAt == null ? 1 : 2,
  status: ChatMessageStatus.sent,
);
