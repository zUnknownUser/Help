import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/foundations/app_colors.dart';
import '../../service_requests/domain/entities/service_request_item.dart';
import '../data/service_review_api.dart';
import 'review_providers.dart';

class ServiceReviewCard extends ConsumerWidget {
  const ServiceReviewCard({required this.request, super.key});
  final ServiceRequestItem request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (request.status != ServiceRequestStatus.completed) {
      return const SizedBox.shrink();
    }
    final reviews = ref.watch(serviceReviewsProvider(request.id));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
      ),
      child: reviews.when(
        loading: () => const LinearProgressIndicator(minHeight: 2),
        error: (_, _) => TextButton.icon(
          onPressed: () => ref.invalidate(serviceReviewsProvider(request.id)),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Carregar avaliação'),
        ),
        data: (items) {
          final role = request.viewerRole.name;
          final mine = items
              .where((item) => item.reviewerRole == role)
              .firstOrNull;
          if (mine != null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sua avaliação',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                _Stars(value: mine.rating),
                if (mine.comment.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    mine.comment,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ],
            );
          }
          return Row(
            children: [
              const Icon(
                Icons.favorite_outline_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Como foi com ${request.counterpartName}?',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const Text(
                      'Sua avaliação é opcional e ajuda a comunidade.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _open(context, ref),
                child: const Text('Avaliar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    var rating = 5;
    var saving = false;
    final comment = TextEditingController();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/animations/heart.gif', height: 76),
              const SizedBox(height: 8),
              Text(
                'Avaliar ${request.counterpartName}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              _Stars(
                value: rating,
                onChanged: (value) => setState(() => rating = value),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: comment,
                maxLength: 800,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Conte como foi (opcional)',
                ),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        setState(() => saving = true);
                        try {
                          await ref
                              .read(serviceReviewApiProvider)
                              .save(request.id, rating, comment.text);
                          if (context.mounted) {
                            Navigator.pop(context, true);
                          }
                        } on ServiceReviewException catch (error) {
                          setState(() => saving = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error.message)),
                            );
                          }
                        }
                      },
                child: Text(saving ? 'Enviando…' : 'Enviar avaliação'),
              ),
            ],
          ),
        ),
      ),
    );
    comment.dispose();
    if (saved == true) {
      ref.invalidate(serviceReviewsProvider(request.id));
      unawaited(ref.read(appStoreReviewServiceProvider).maybeRequest());
    }
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.value, this.onChanged});
  final int value;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(
      5,
      (index) => IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: onChanged == null ? null : () => onChanged!(index + 1),
        icon: Icon(
          index < value ? Icons.star_rounded : Icons.star_border_rounded,
          color: AppColors.amber,
        ),
      ),
    ),
  );
}
