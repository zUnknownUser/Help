import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/components/app_loading.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../../data/providers/chat_data_providers.dart';
import '../../data/realtime/chat_realtime_coordinator.dart';
import '../../domain/entities/chat_conversation.dart';
import '../providers/chat_providers.dart';
import '../widgets/chat_contact_sheet.dart';
import '../widgets/conversation_tile.dart';
import '../widgets/conversation_list_chrome.dart';
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
  String? _decidingId;
  Timer? _debounce;
  ConversationFilter _filter = ConversationFilter.all;

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
    final connection =
        ref.watch(realtimeConnectionProvider).value ??
        RealtimeConnectionStatus.disconnected;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Conversas'),
        actions: [
          IconButton(
            tooltip: 'Nova conversa',
            onPressed: _newConversation,
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nova conversa',
        onPressed: _newConversation,
        child: const Icon(Icons.edit_rounded),
      ),
      body: Column(
        children: [
          ConversationListToolbar(
            controller: _search,
            selected: _filter,
            onQueryChanged: _onSearch,
            onFilterChanged: (filter) => setState(() => _filter = filter),
          ),
          if (connection != RealtimeConnectionStatus.connected)
            ChatConnectionBanner(status: connection),
          Expanded(
            child: conversations.when(
              data: (items) => _conversationList(_applyFilter(items)),
              loading: () =>
                  const AppLoadingView(message: 'Abrindo conversas…'),
              error: (_, _) => const Center(
                child: Text('Não foi possível abrir as conversas.'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _conversationList(List<ChatConversation> items) {
    if (items.isEmpty) {
      return EmptyConversationsView(
        filtered: _query.isNotEmpty || _filter != ConversationFilter.all,
      );
    }
    final currentUserId = ref.read(currentChatUserIdProvider);
    return RefreshIndicator(
      onRefresh: () => ref
          .read(chatRealtimeCoordinatorProvider)
          .loadMoreConversations(query: _query, reset: true),
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 92),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, index) {
          final conversation = items[index];
          return RepaintBoundary(
            key: ValueKey(conversation.id),
            child: ConversationTile(
              conversation: conversation,
              currentUserId: currentUserId,
              deciding: _decidingId == conversation.id,
              onTap: () => _open(conversation),
              onAvatarTap: () => showChatContactSheet(
                context,
                conversation,
                onOpenConversation: () => _open(conversation),
              ),
              onAccept: () => _decide(conversation, accept: true),
              onDecline: () => _confirmDecline(conversation),
            ),
          );
        },
      ),
    );
  }

  List<ChatConversation> _applyFilter(List<ChatConversation> items) =>
      switch (_filter) {
        ConversationFilter.all => items,
        ConversationFilter.unread =>
          items
              .where((conversation) => conversation.unreadCount > 0)
              .toList(growable: false),
        ConversationFilter.requests =>
          items
              .where(
                (conversation) =>
                    conversation.status == ChatConversationStatus.pending,
              )
              .toList(growable: false),
      };

  void _onSearch(String value) {
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
  }

  void _loadNextPage() {
    if (!_scroll.hasClients || _scroll.position.extentAfter > 500) return;
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

  Future<void> _decide(
    ChatConversation conversation, {
    required bool accept,
  }) async {
    setState(() => _decidingId = conversation.id);
    try {
      await ref
          .read(chatRealtimeCoordinatorProvider)
          .decideConversation(conversation.id, accept: accept);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível responder à solicitação.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _decidingId = null);
    }
  }

  Future<void> _confirmDecline(ChatConversation conversation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recusar conversa?'),
        content: Text(
          '${conversation.otherDisplayName} não poderá enviar mensagens para você.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Recusar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _decide(conversation, accept: false);
  }

  void _open(ChatConversation conversation) => Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => ChatPage(conversation: conversation)),
  );
}
