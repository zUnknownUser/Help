import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../data/providers/chat_data_providers.dart';
import '../../data/realtime/chat_realtime_coordinator.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';
import '../providers/chat_providers.dart';
import '../widgets/chat_avatar.dart';
import '../widgets/message_status_icon.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({required this.conversation, super.key});
  final ChatConversation conversation;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  Timer? _typingTimer;
  bool _typingSent = false;
  bool _loadingOlder = false;
  bool _canLoadOlder = true;
  int _newMessages = 0;
  int _previousMaxSequence = 0;
  int _lastReadSent = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialSync());
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    if (_typingSent) {
      ref
          .read(chatRealtimeCoordinatorProvider)
          .typing(widget.conversation.id, false);
    }
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider(widget.conversation.id));
    final typing =
        ref.watch(typingProvider(widget.conversation.id)).value ?? false;
    final online =
        ref
            .watch(userPresenceProvider(widget.conversation.otherUserId))
            .value ??
        false;
    final connection =
        ref.watch(realtimeConnectionProvider).value ??
        RealtimeConnectionStatus.disconnected;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F4),
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            ChatAvatar(name: widget.conversation.otherDisplayName, radius: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.conversation.otherDisplayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    typing
                        ? 'digitando…'
                        : online
                        ? 'online'
                        : connection == RealtimeConnectionStatus.connected
                        ? 'offline'
                        : 'conectando…',
                    style: TextStyle(
                      fontSize: 10,
                      color: typing || online
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          messages.when(
            data: (items) {
              _afterMessages(items);
              if (items.isEmpty) {
                return const Center(child: Text('Envie a primeira mensagem.'));
              }
              return ListView.builder(
                controller: _scroll,
                reverse: true,
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 92),
                itemCount: items.length + (_loadingOlder ? 1 : 0),
                itemBuilder: (_, index) {
                  if (index == items.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  final message = items[items.length - 1 - index];
                  return RepaintBoundary(
                    key: ValueKey(message.clientId),
                    child: _MessageBubble(
                      message: message,
                      mine:
                          message.senderId ==
                          ref.read(currentChatUserIdProvider),
                      onRetry: message.status == ChatMessageStatus.failed
                          ? () => ref
                                .read(chatRealtimeCoordinatorProvider)
                                .retry(message.clientId)
                          : null,
                    ),
                  );
                },
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (_, _) => const Center(
              child: Text('Não foi possível abrir as mensagens locais.'),
            ),
          ),
          if (_newMessages > 0)
            Positioned(
              right: 16,
              bottom: 86,
              child: FloatingActionButton.small(
                onPressed: _jumpToLatest,
                child: Badge(
                  label: Text('$_newMessages'),
                  child: const Icon(Icons.keyboard_arrow_down_rounded),
                ),
              ),
            ),
        ],
      ),
      bottomSheet: _Composer(
        controller: _input,
        focusNode: _focus,
        onChanged: _onTyping,
        onSend: _send,
      ),
    );
  }

  Future<void> _initialSync() async {
    final loaded = await ref
        .read(chatRealtimeCoordinatorProvider)
        .loadOlder(widget.conversation.id);
    if (mounted && !loaded) setState(() => _canLoadOlder = false);
  }

  void _afterMessages(List<ChatMessage> items) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final latestSequence = items.fold<int>(
        0,
        (value, message) =>
            (message.sequence ?? 0) > value ? message.sequence! : value,
      );
      final currentUserId = ref.read(currentChatUserIdProvider);
      final incomingAdded = _previousMaxSequence == 0
          ? 0
          : items
                .where(
                  (message) =>
                      message.senderId != currentUserId &&
                      (message.sequence ?? 0) > _previousMaxSequence,
                )
                .length;
      if (incomingAdded > 0) {
        if (_atBottom) {
          _scroll.animateTo(
            0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        } else {
          setState(() => _newMessages += incomingAdded);
        }
      }
      _previousMaxSequence = latestSequence;
      if (_atBottom) _markVisibleRead(items, currentUserId);
    });
  }

  void _markVisibleRead(List<ChatMessage> items, String currentUserId) {
    final latestIncoming = items
        .where(
          (message) =>
              message.senderId != currentUserId && message.sequence != null,
        )
        .fold<int>(
          0,
          (max, message) => message.sequence! > max ? message.sequence! : max,
        );
    if (latestIncoming > _lastReadSent) {
      _lastReadSent = latestIncoming;
      unawaited(
        ref
            .read(chatRealtimeCoordinatorProvider)
            .markRead(widget.conversation.id, latestIncoming),
      );
    }
  }

  void _onScroll() {
    if (_atBottom) {
      if (_newMessages > 0) setState(() => _newMessages = 0);
      final messages = ref.read(messagesProvider(widget.conversation.id)).value;
      if (messages != null) {
        _markVisibleRead(messages, ref.read(currentChatUserIdProvider));
      }
    }
    if (!_loadingOlder &&
        _canLoadOlder &&
        _scroll.hasClients &&
        _scroll.position.extentAfter < 180) {
      _loadingOlder = true;
      ref
          .read(chatRealtimeCoordinatorProvider)
          .loadOlder(widget.conversation.id)
          .then((loaded) {
            if (mounted && !loaded) setState(() => _canLoadOlder = false);
          })
          .whenComplete(() {
            if (mounted) setState(() => _loadingOlder = false);
          });
    }
  }

  bool get _atBottom => !_scroll.hasClients || _scroll.offset < 80;

  void _jumpToLatest() {
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
    setState(() => _newMessages = 0);
  }

  void _onTyping(String value) {
    final coordinator = ref.read(chatRealtimeCoordinatorProvider);
    if (!_typingSent && value.trim().isNotEmpty) {
      _typingSent = true;
      coordinator.typing(widget.conversation.id, true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(milliseconds: 1400), () {
      if (_typingSent) coordinator.typing(widget.conversation.id, false);
      _typingSent = false;
    });
  }

  Future<void> _send() async {
    final content = _input.text.trim();
    if (content.isEmpty) return;
    _input.clear();
    _typingTimer?.cancel();
    if (_typingSent) {
      ref
          .read(chatRealtimeCoordinatorProvider)
          .typing(widget.conversation.id, false);
    }
    _typingSent = false;
    await ref
        .read(chatRealtimeCoordinatorProvider)
        .send(widget.conversation.id, content);
    _jumpToLatest();
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    this.onRetry,
  });
  final ChatMessage message;
  final bool mine;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Align(
    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
    child: GestureDetector(
      onTap: onRetry,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .78,
        ),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(11, 8, 8, 6),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFFDDF2E3) : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 3),
            bottomRight: Radius.circular(mine ? 3 : 14),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                message.content,
                style: const TextStyle(fontSize: 14, height: 1.3),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _time(message.displayedAt),
              style: const TextStyle(
                fontSize: 9,
                color: AppColors.textSecondary,
              ),
            ),
            if (mine) ...[
              const SizedBox(width: 3),
              MessageStatusIcon(status: message.status, size: 13),
            ],
          ],
        ),
      ),
    ),
  );

  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSend,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Mensagem',
                prefixIcon: Icon(Icons.sentiment_satisfied_alt_outlined),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: 'Enviar',
            onPressed: onSend,
            icon: const Icon(Icons.send_rounded),
          ),
        ],
      ),
    ),
  );
}
