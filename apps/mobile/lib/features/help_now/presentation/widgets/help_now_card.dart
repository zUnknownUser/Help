import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/entities/help_now_request.dart';

class HelpNowCard extends StatelessWidget {
  const HelpNowCard({required this.onTap, this.request, super.key});

  final HelpNowRequest? request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = request?.active ?? false;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('help_now_card'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(16, 15, 14, 15),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF0F8F2), Color(0xFFFAFCFA)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFD8EBDD)),
          ),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x244F9E6C),
                      blurRadius: 14,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  active ? Icons.radar_rounded : Icons.bolt_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Flexible(
                          child: Text(
                            'Help Agora',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (active) ...[
                          const SizedBox(width: 7),
                          const _LivePill(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      active
                          ? _activeLabel(request!)
                          : 'Atendimento próximo quando você precisa agora',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _activeLabel(HelpNowRequest request) =>
    request.status == HelpNowStatus.assigned
    ? '${request.assignedProviderName} aceitou seu chamado'
    : 'Buscando profissionais para ${request.categoryName}';

class _LivePill extends StatelessWidget {
  const _LivePill();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Text(
      'ATIVO',
      style: TextStyle(
        color: AppColors.primaryDark,
        fontSize: 8,
        fontWeight: FontWeight.w900,
        letterSpacing: .5,
      ),
    ),
  );
}
