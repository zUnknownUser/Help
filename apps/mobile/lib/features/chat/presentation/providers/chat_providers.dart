import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/providers/auth_data_providers.dart';
import '../../data/providers/chat_data_providers.dart';
import '../../data/realtime/chat_realtime_coordinator.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';

final conversationsProvider = StreamProvider.autoDispose
    .family<List<ChatConversation>, String>(
      (ref, query) => ref
          .watch(chatRealtimeCoordinatorProvider)
          .watchConversations(query: query),
    );

final messagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, String>(
      (ref, conversationId) => ref
          .watch(chatRealtimeCoordinatorProvider)
          .watchMessages(conversationId),
    );

final unreadChatCountProvider = StreamProvider<int>(
  (ref) => ref
      .watch(chatRealtimeCoordinatorProvider)
      .watchConversations()
      .map((items) => items.fold(0, (total, item) => total + item.unreadCount)),
);

final realtimeConnectionProvider = StreamProvider<RealtimeConnectionStatus>(
  (ref) => ref.watch(chatRealtimeCoordinatorProvider).connectionStatus,
);

final currentChatUserIdProvider = Provider<String>(
  (ref) => ref.watch(firebaseAuthProvider).currentUser?.uid ?? '',
);

final typingProvider = StreamProvider.autoDispose.family<bool, String>(
  (ref, conversationId) =>
      ref.watch(chatRealtimeCoordinatorProvider).watchTyping(conversationId),
);

final userPresenceProvider = StreamProvider.autoDispose
    .family<PresenceEvent, String>(
      (ref, userId) =>
          ref.watch(chatRealtimeCoordinatorProvider).watchPresence(userId),
    );
