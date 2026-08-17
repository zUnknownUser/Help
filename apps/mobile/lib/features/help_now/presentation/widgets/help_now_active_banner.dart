import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/entities/help_now_request.dart';

class HelpNowActiveBanner extends StatelessWidget {
  const HelpNowActiveBanner({
    required this.request,
    required this.onTap,
    super.key,
  });
  final HelpNowRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.primaryDark,
    child: SafeArea(
      top: false,
      bottom: false,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
          child: Row(
            children: [
              Icon(
                request.status == HelpNowStatus.assigned
                    ? Icons.check_circle_rounded
                    : Icons.radar_rounded,
                color: Colors.white,
                size: 19,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  request.status == HelpNowStatus.assigned
                      ? '${request.assignedProviderName} aceitou • Ver atendimento'
                      : 'Help Agora buscando profissionais…',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
