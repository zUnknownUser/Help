import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/components/app_loading.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../../data/providers/chat_data_providers.dart';
import '../../domain/entities/chat_conversation.dart';
import '../widgets/chat_user_sheet.dart';
import '../widgets/chat_user_tile.dart';

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
  Object? _error;
  int _loadGeneration = 0;

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
    appBar: AppBar(
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nova conversa'),
          Text(
            'Encontre quem faz sentido para você',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
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
              hintText: 'Buscar por nome',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const AppLoadingView(message: 'Buscando pessoas…')
              : _error != null && _users.isEmpty
              ? _UserLoadError(onRetry: () => _load(reset: true))
              : _users.isEmpty
              ? const _EmptyUsers()
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.only(top: 5, bottom: 24),
                  itemCount: _users.length + (_loadingMore ? 1 : 0),
                  itemBuilder: (_, index) {
                    if (index == _users.length) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: AppProgressIndicator()),
                      );
                    }
                    final user = _users[index];
                    return RepaintBoundary(
                      child: ChatUserTile(
                        user: user,
                        loading: _openingUser == user.id,
                        onView: () => showChatUserSheet(
                          context,
                          user,
                          onStart: () => _open(user),
                        ),
                        onOpen: _openingUser == null ? () => _open(user) : null,
                      ),
                    );
                  },
                ),
        ),
      ],
    ),
  );

  Future<void> _load({required bool reset}) async {
    final generation = reset ? ++_loadGeneration : _loadGeneration;
    final cursor = reset ? '' : _cursor;
    final query = _search.text.trim();
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final page = await ref
          .read(chatRealtimeCoordinatorProvider)
          .users(query: query, cursor: cursor);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        if (reset) _users.clear();
        final ids = _users.map((item) => item.id).toSet();
        _users.addAll(page.items.where((item) => ids.add(item.id)));
        _cursor = page.nextCursor;
      });
    } catch (error) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir a conversa.')),
        );
      }
    } finally {
      if (mounted) setState(() => _openingUser = null);
    }
  }
}

class _EmptyUsers extends StatelessWidget {
  const _EmptyUsers();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_search_rounded, color: AppColors.primary, size: 42),
          SizedBox(height: 12),
          Text(
            'Nenhuma pessoa disponível',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'Profissionais veem somente clientes relacionados às suas solicitações. Clientes veem profissionais aprovados e disponíveis.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class _UserLoadError extends StatelessWidget {
  const _UserLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: AppColors.primary,
            size: 40,
          ),
          const SizedBox(height: 12),
          const Text(
            'Não foi possível buscar pessoas agora.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onRetry,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    ),
  );
}
