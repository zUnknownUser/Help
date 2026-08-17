import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../../core/design_system/components/app_loading.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../calls/domain/entities/call_session.dart';
import '../../../calls/presentation/pages/call_page.dart';
import '../../../calls/presentation/providers/call_providers.dart';
import '../../data/providers/chat_data_providers.dart';
import '../../data/realtime/chat_realtime_coordinator.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';
import '../providers/chat_providers.dart';
import '../widgets/chat_composer.dart';
import '../widgets/chat_header.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/chat_contact_sheet.dart';
import '../widgets/conversation_access_view.dart';

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
  ChatMessage? _editingMessage;
  bool _typingSent = false;
  bool _loadingOlder = false;
  bool _canLoadOlder = true;
  int _newMessages = 0;
  int _previousMaxSequence = 0;
  int _lastReadSent = 0;
  bool _deciding = false;
  bool _recording = false;
  bool _recordingStarting = false;
  bool _stopRecordingRequested = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    if (widget.conversation.canMessage) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _initialSync());
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _recordingTimer?.cancel();
    if (_recording || _recordingStarting) {
      unawaited(ref.read(voiceRecorderProvider).cancel());
    }
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
    final conversation = _currentConversation();
    final messages = ref.watch(messagesProvider(widget.conversation.id));
    final typing =
        ref.watch(typingProvider(widget.conversation.id)).value ?? false;
    final presence =
        ref
            .watch(userPresenceProvider(widget.conversation.otherUserId))
            .value ??
        PresenceEvent(userId: widget.conversation.otherUserId, online: false);
    final connection =
        ref.watch(realtimeConnectionProvider).value ??
        RealtimeConnectionStatus.disconnected;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F4),
      appBar: AppBar(
        titleSpacing: 0,
        title: ChatHeader(
          name: conversation.otherDisplayName,
          presence: presence,
          connection: connection,
          typing: typing,
          onTap: () => showChatContactSheet(context, conversation),
        ),
        actions: conversation.canMessage
            ? [
                IconButton(
                  tooltip: 'Chamada de voz',
                  onPressed: () => _startCall(CallMediaType.audio),
                  icon: const Icon(Icons.call_outlined),
                ),
                IconButton(
                  tooltip: 'Chamada de video',
                  onPressed: () => _startCall(CallMediaType.video),
                  icon: const Icon(Icons.videocam_outlined),
                ),
              ]
            : null,
      ),
      body: conversation.canMessage
          ? Stack(
              children: [
                messages.when(
                  data: _messageList,
                  loading: () => const AppLoadingView(
                    message: 'Abrindo mensagens…',
                    compact: true,
                  ),
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
            )
          : ConversationAccessView(
              conversation: conversation,
              loading: _deciding,
              onAccept: () => _decide(accept: true),
              onDecline: _confirmDecline,
            ),
      bottomSheet: conversation.canMessage
          ? ChatComposer(
              controller: _input,
              focusNode: _focus,
              onChanged: _onTyping,
              onSend: _send,
              editing: _editingMessage != null,
              onCancelEdit: _cancelEditing,
              recording: _recording,
              recordingDuration: _recordingDuration,
              onRecordStart: _startRecording,
              onRecordStop: _stopRecording,
              onRecordCancel: _cancelRecording,
            )
          : null,
    );
  }

  ChatConversation _currentConversation() {
    final values = ref.watch(conversationsProvider('')).value;
    if (values != null) {
      for (final conversation in values) {
        if (conversation.id == widget.conversation.id) return conversation;
      }
    }
    return widget.conversation;
  }

  Future<void> _decide({required bool accept}) async {
    setState(() => _deciding = true);
    try {
      await ref
          .read(chatRealtimeCoordinatorProvider)
          .decideConversation(widget.conversation.id, accept: accept);
      if (accept) unawaited(_initialSync());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível responder à solicitação.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deciding = false);
    }
  }

  Future<void> _confirmDecline() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recusar conversa?'),
        content: const Text(
          'A outra pessoa não poderá enviar mensagens para você.',
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
    if (confirmed == true) await _decide(accept: false);
  }

  Widget _messageList(List<ChatMessage> items) {
    _afterMessages(items);
    if (items.isEmpty) {
      return const Center(child: Text('Envie a primeira mensagem.'));
    }
    final currentUserId = ref.read(currentChatUserIdProvider);
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 92),
      itemCount: items.length + (_loadingOlder ? 1 : 0),
      itemBuilder: (_, index) {
        if (index == items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: AppProgressIndicator()),
          );
        }
        final message = items[items.length - 1 - index];
        final mine = message.senderId == currentUserId;
        return RepaintBoundary(
          key: ValueKey(message.clientId),
          child: ChatMessageBubble(
            message: message,
            mine: mine,
            onRetry: message.status == ChatMessageStatus.failed
                ? () => ref
                      .read(chatRealtimeCoordinatorProvider)
                      .retry(message.clientId)
                : null,
            onLongPress: mine && !message.isDeleted
                ? () => _showMessageActions(message)
                : null,
          ),
        );
      },
    );
  }

  Future<void> _initialSync() async {
    try {
      final loaded = await ref
          .read(chatRealtimeCoordinatorProvider)
          .loadOlder(widget.conversation.id);
      if (mounted && !loaded) setState(() => _canLoadOlder = false);
    } catch (_) {
      AppLogger.realtime(
        'history_initial_load_failed',
        fields: {'conversation_id': widget.conversation.id},
      );
    }
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
    if (latestIncoming <= _lastReadSent) return;
    _lastReadSent = latestIncoming;
    unawaited(
      ref
          .read(chatRealtimeCoordinatorProvider)
          .markRead(widget.conversation.id, latestIncoming),
    );
  }

  void _onScroll() {
    if (_atBottom) {
      if (_newMessages > 0) setState(() => _newMessages = 0);
      final messages = ref.read(messagesProvider(widget.conversation.id)).value;
      if (messages != null) {
        _markVisibleRead(messages, ref.read(currentChatUserIdProvider));
      }
    }
    if (_loadingOlder ||
        !_canLoadOlder ||
        !_scroll.hasClients ||
        _scroll.position.extentAfter >= 180) {
      return;
    }
    setState(() => _loadingOlder = true);
    unawaited(_loadOlder());
  }

  Future<void> _loadOlder() async {
    try {
      final loaded = await ref
          .read(chatRealtimeCoordinatorProvider)
          .loadOlder(widget.conversation.id);
      if (mounted && !loaded) setState(() => _canLoadOlder = false);
    } catch (_) {
      AppLogger.realtime(
        'history_page_load_failed',
        fields: {'conversation_id': widget.conversation.id},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível carregar mensagens antigas.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  bool get _atBottom => !_scroll.hasClients || _scroll.offset < 80;

  void _jumpToLatest() {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
    if (_newMessages > 0) setState(() => _newMessages = 0);
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
    _stopTyping();
    final editing = _editingMessage;
    if (editing == null) {
      await ref
          .read(chatRealtimeCoordinatorProvider)
          .send(widget.conversation.id, content);
    } else {
      setState(() => _editingMessage = null);
      if (content != editing.content) {
        await ref.read(chatRealtimeCoordinatorProvider).edit(editing, content);
      }
    }
    _jumpToLatest();
  }

  Future<void> _startCall(CallMediaType mediaType) async {
    try {
      final start = ref
          .read(callSessionControllerProvider)
          .startOutgoing(_currentConversation(), mediaType);
      if (!mounted) return;
      final route = Navigator.of(context).push<void>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const CallPage(),
        ),
      );
      await start;
      await route;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nao foi possivel iniciar a chamada agora.'),
        ),
      );
    }
  }

  Future<void> _startRecording() async {
    if (_recording || _recordingStarting) return;
    _focus.unfocus();
    _recordingStarting = true;
    _stopRecordingRequested = false;
    try {
      await ref.read(voiceRecorderProvider).start();
      if (!mounted) return;
      setState(() {
        _recording = true;
        _recordingDuration = Duration.zero;
      });
      _recordingTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted) return;
        final elapsed = ref.read(voiceRecorderProvider).elapsed;
        setState(() => _recordingDuration = elapsed);
        if (elapsed >= const Duration(minutes: 5)) unawaited(_stopRecording());
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permita o uso do microfone para gravar audios.'),
          ),
        );
      }
    } finally {
      _recordingStarting = false;
    }
    if (_stopRecordingRequested) await _stopRecording();
  }

  Future<void> _stopRecording() async {
    if (_recordingStarting) {
      _stopRecordingRequested = true;
      return;
    }
    if (!_recording) return;
    _recordingTimer?.cancel();
    _recordingTimer = null;
    setState(() => _recording = false);
    final voice = await ref.read(voiceRecorderProvider).stop();
    if (voice == null) return;
    if (voice.duration < const Duration(milliseconds: 500)) {
      try {
        await File(voice.path).delete();
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Segure um pouco mais para gravar.')),
        );
      }
      return;
    }
    await ref
        .read(chatRealtimeCoordinatorProvider)
        .sendVoice(
          widget.conversation.id,
          localPath: voice.path,
          duration: voice.duration,
        );
    _jumpToLatest();
  }

  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    if (mounted) {
      setState(() {
        _recording = false;
        _recordingDuration = Duration.zero;
      });
    }
    await ref.read(voiceRecorderProvider).cancel();
  }

  Future<void> _showMessageActions(ChatMessage message) async {
    final action = await showModalBottomSheet<_MessageAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            if (!message.isVoice)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Editar mensagem'),
                onTap: () => Navigator.pop(context, _MessageAction.edit),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Apagar mensagem'),
              textColor: AppColors.danger,
              iconColor: AppColors.danger,
              onTap: () => Navigator.pop(context, _MessageAction.delete),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == _MessageAction.edit) {
      setState(() => _editingMessage = message);
      _input.text = message.content;
      _input.selection = TextSelection.collapsed(offset: _input.text.length);
      _focus.requestFocus();
    } else if (action == _MessageAction.delete) {
      await _confirmDelete(message);
    }
  }

  Future<void> _confirmDelete(ChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar mensagem?'),
        content: const Text(
          'Ela será substituída por “Mensagem apagada” para todos na conversa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(chatRealtimeCoordinatorProvider).delete(message);
    }
  }

  void _cancelEditing() {
    _input.clear();
    setState(() => _editingMessage = null);
  }

  void _stopTyping() {
    _typingTimer?.cancel();
    if (_typingSent) {
      ref
          .read(chatRealtimeCoordinatorProvider)
          .typing(widget.conversation.id, false);
    }
    _typingSent = false;
  }
}

enum _MessageAction { edit, delete }
