import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../data/providers/chat_data_providers.dart';
import '../../domain/entities/chat_conversation.dart';
import '../widgets/chat_avatar.dart';

class NewConversationPage extends ConsumerStatefulWidget {
  const NewConversationPage({super.key});

  @override
  ConsumerState<NewConversationPage> createState() =>
      _NewConversationPageState();
}

class _NewConversationPageState extends ConsumerState<NewConversationPage> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _users = <ChatUser>[];
  Timer? _debounce;
  String _cursor = '';
  bool _loading = true;
  bool _loadingMore = false;
  String? _openingUser;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_cursor.isNotEmpty &&
          !_loadingMore &&
          _scroll.position.extentAfter < 350) {
        _load(reset: false);
      }
    });
    unawaited(_load(reset: true));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Nova conversa')),
    body: Column(
      children: [
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 7, 16, 14),
          child: TextField(
            controller: _search,
            autofocus: true,
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(
                const Duration(milliseconds: 350),
                () => _load(reset: true),
              );
            },
            decoration: const InputDecoration(
              hintText: 'Buscar pessoa',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _users.isEmpty
              ? const Center(child: Text('Nenhum usuário encontrado.'))
              : ListView.builder(
                  controller: _scroll,
                  itemCount: _users.length + (_loadingMore ? 1 : 0),
                  itemBuilder: (_, index) {
                    if (index == _users.length) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    final user = _users[index];
                    return ListTile(
                      tileColor: AppColors.surface,
                      leading: ChatAvatar(name: user.displayName),
                      title: Text(
                        user.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      trailing: _openingUser == user.id
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: _openingUser == null ? () => _open(user) : null,
                    );
                  },
                ),
        ),
      ],
    ),
  );

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() => _loading = true);
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final page = await ref
          .read(chatRealtimeCoordinatorProvider)
          .users(query: _search.text, cursor: reset ? '' : _cursor);
      if (!mounted) return;
      setState(() {
        if (reset) _users.clear();
        final ids = _users.map((item) => item.id).toSet();
        _users.addAll(page.items.where((item) => ids.add(item.id)));
        _cursor = page.nextCursor;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _open(ChatUser user) async {
    setState(() => _openingUser = user.id);
    try {
      final conversation = await ref
          .read(chatRealtimeCoordinatorProvider)
          .startDirect(user.id);
      if (mounted) Navigator.of(context).pop<ChatConversation>(conversation);
    } finally {
      if (mounted) setState(() => _openingUser = null);
    }
  }
}
