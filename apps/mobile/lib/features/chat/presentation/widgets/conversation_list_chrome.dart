import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../data/realtime/chat_realtime_coordinator.dart';

enum ConversationFilter { all, unread, requests }

class ConversationListToolbar extends StatelessWidget {
  const ConversationListToolbar({
    required this.controller,
    required this.selected,
    required this.onQueryChanged,
    required this.onFilterChanged,
    super.key,
  });

  final TextEditingController controller;
  final ConversationFilter selected;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<ConversationFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.surface,
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
    child: Column(
      children: [
        TextField(
          controller: controller,
          onChanged: onQueryChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Pesquisar conversas',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpar busca',
                    onPressed: () {
                      controller.clear();
                      onQueryChanged('');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: ConversationFilter.values
              .map(
                (filter) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_filterLabel(filter)),
                    selected: selected == filter,
                    onSelected: (_) => onFilterChanged(filter),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ],
    ),
  );
}

class ChatConnectionBanner extends StatelessWidget {
  const ChatConnectionBanner({required this.status, super.key});

  final RealtimeConnectionStatus status;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: AppColors.primarySoft,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
    child: Text(
      status == RealtimeConnectionStatus.connecting
          ? 'Conectando… suas conversas continuam disponíveis'
          : 'Sem conexão • novas mensagens serão sincronizadas depois',
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppColors.primaryDark, fontSize: 10),
    ),
  );
}

class EmptyConversationsView extends StatelessWidget {
  const EmptyConversationsView({required this.filtered, super.key});

  final bool filtered;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.forum_outlined, size: 48, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(
            filtered ? 'Nenhuma conversa encontrada' : 'Nenhuma conversa ainda',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            filtered
                ? 'Tente outro nome ou selecione “Todas”.'
                : 'Inicie um contato. A outra pessoa precisará aceitar quando ainda não houver um pedido.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

String _filterLabel(ConversationFilter filter) => switch (filter) {
  ConversationFilter.all => 'Todas',
  ConversationFilter.unread => 'Não lidas',
  ConversationFilter.requests => 'Solicitações',
};
