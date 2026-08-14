import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../data/providers/chat_data_providers.dart';
import '../../domain/entities/chat_conversation.dart';
import '../providers/chat_providers.dart';
import '../widgets/chat_avatar.dart';
import '../widgets/message_status_icon.dart';
import 'chat_page.dart';
import 'new_conversation_page.dart';

class ChatListPage extends ConsumerStatefulWidget {
  const ChatListPage({super.key});

  @override
  ConsumerState<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends ConsumerState<ChatListPage> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  String _query = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_loadNextPage);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationsProvider(_query));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Conversas')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nova conversa',
        onPressed: _newConversation,
        child: const Icon(Icons.edit_rounded),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            child: TextField(
              controller: _search,
              onChanged: (value) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 250), () {
                  if (!mounted) return;
                  setState(() => _query = value.trim());
                  unawaited(
                    ref
                        .read(chatRealtimeCoordinatorProvider)
                        .loadMoreConversations(query: _query, reset: true),
                  );
                });
              },
              decoration: const InputDecoration(
                hintText: 'Buscar conversas',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: conversations.when(
              data: (items) => items.isEmpty
                  ? const _EmptyConversations()
                  : ListView.separated(
                      controller: _scroll,
                      itemCount: items.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, indent: 76),
                      itemBuilder: (_, index) => _ConversationTile(
                        conversation: items[index],
                        currentUserId: ref.read(currentChatUserIdProvider),
                        onTap: () => _open(items[index]),
                      ),
                    ),
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, _) => const Center(
                child: Text('Não foi possível abrir as conversas.'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _loadNextPage() {
    if (!_scroll.hasClients || _scroll.position.extentAfter > 500) {
      return;
    }
    unawaited(
      ref
          .read(chatRealtimeCoordinatorProvider)
          .loadMoreConversations(query: _query),
    );
  }

  Future<void> _newConversation() async {
    final conversation = await Navigator.of(context).push<ChatConversation>(
      MaterialPageRoute(builder: (_) => const NewConversationPage()),
    );
    if (conversation != null && mounted) _open(conversation);
  }

  void _open(ChatConversation conversation) => Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => ChatPage(conversation: conversation)),
  );
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
  });
  final ChatConversation conversation;
  final String currentUserId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final last = conversation.lastMessage;
    return ListTile(
      tileColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      leading: ChatAvatar(name: conversation.otherDisplayName),
      title: Text(
        conversation.otherDisplayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Row(
        children: [
          if (last?.senderId == currentUserId) ...[
            MessageStatusIcon(status: last!.status, size: 13),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              last?.content ?? 'Inicie a conversa',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _time(last?.displayedAt ?? conversation.updatedAt),
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          if (conversation.unreadCount > 0)
            Container(
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                conversation.unreadCount > 99
                    ? '99+'
                    : '${conversation.unreadCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
      onTap: onTap,
    );
  }

  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _EmptyConversations extends StatelessWidget {
  const _EmptyConversations();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined, size: 48, color: AppColors.primary),
          SizedBox(height: 12),
          Text(
            'Nenhuma conversa ainda',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 5),
          Text(
            'Toque no botão abaixo para conversar com outro usuário.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
