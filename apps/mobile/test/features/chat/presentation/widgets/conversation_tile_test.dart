import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/chat/domain/entities/chat_conversation.dart';
import 'package:help/features/chat/presentation/widgets/conversation_tile.dart';

void main() {
  testWidgets('solicitação recebida exige decisão antes da conversa', (
    tester,
  ) async {
    var accepted = false;
    var declined = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConversationTile(
            conversation: ChatConversation(
              id: 'conversation',
              otherUserId: 'other',
              otherDisplayName: 'Maria',
              updatedAt: DateTime(2026, 8, 16),
              status: ChatConversationStatus.pending,
            ),
            currentUserId: 'me',
            onTap: () {},
            onAvatarTap: () {},
            onAccept: () => accepted = true,
            onDecline: () => declined = true,
          ),
        ),
      ),
    );

    expect(find.text('Quer iniciar uma conversa com você'), findsOneWidget);
    expect(find.text('Aceitar'), findsOneWidget);
    expect(find.text('Recusar'), findsOneWidget);

    await tester.tap(find.text('Aceitar'));
    await tester.tap(find.text('Recusar'));
    expect(accepted, isTrue);
    expect(declined, isTrue);
  });
}
