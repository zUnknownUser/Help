import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_loading.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../home/presentation/pages/home_page.dart';
import '../../../main_navigation/presentation/main_shell.dart';
import '../../../main_navigation/presentation/main_shell_controller.dart';
import '../../../main_navigation/presentation/main_tab.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/failures/profile_failure.dart';
import '../controllers/profile_controller.dart';
import '../providers/profile_providers.dart';
import 'profile_setup_page.dart';
import 'provider_home_page.dart';
import '../../../../core/session/session_lifecycle.dart';
import '../../../notifications/data/push_providers.dart';
import '../../../notifications/data/push_registration_service.dart';
import '../../../service_requests/presentation/pages/service_request_details_page.dart';
import '../../../chat/data/providers/chat_data_providers.dart';
import '../../../chat/presentation/pages/chat_page.dart';
import '../../../calls/domain/entities/call_session.dart';
import '../../../calls/presentation/pages/call_page.dart';
import '../../../calls/presentation/providers/call_providers.dart';

class ProfileGate extends ConsumerStatefulWidget {
  const ProfileGate({required this.user, super.key});

  final AuthUser user;

  @override
  ConsumerState<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends ConsumerState<ProfileGate> {
  final _navigation = MainShellController();
  String? _activeCallRouteId;

  @override
  void dispose() {
    _navigation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pushEventProvider, (_, next) {
      next.whenData((event) => _handlePush(context, ref, event));
    });
    ref.listen(callSessionStateProvider, (_, next) {
      next.whenData((session) => _handleCallSession(context, ref, session));
    });
    final state = ref.watch(currentProfileProvider);
    return state.when(
      data: (profile) => SessionLifecycle(
        userId: widget.user.id,
        child: MainShell(
          key: ValueKey(profile.activeRole),
          controller: _navigation,
          homeBuilder: (onTabSelected) =>
              profile.activeRole == UserRole.provider
              ? ProviderHomePage(profile: profile, onTabSelected: onTabSelected)
              : HomePage(onTabSelected: onTabSelected),
        ),
      ),
      loading: () => const Scaffold(
        backgroundColor: AppColors.surface,
        body: AppLoadingView(message: 'Carregando seu perfil…'),
      ),
      error: (error, _) {
        final failure = error is ProfilePresentationException
            ? error.failure
            : const ProfileFailure(ProfileFailureType.unknown);
        if (failure.type == ProfileFailureType.notFound) {
          return ProfileSetupPage(initialDisplayName: widget.user.displayName);
        }
        return _ProfileErrorPage(
          onRetry: ref.read(currentProfileProvider.notifier).retry,
        );
      },
    );
  }

  Future<void> _handleCallSession(
    BuildContext context,
    WidgetRef ref,
    CallSession? session,
  ) async {
    if (session == null ||
        session.phase != CallPhase.incoming ||
        _activeCallRouteId == session.id) {
      return;
    }
    _activeCallRouteId = session.id;
    final conversation = await ref
        .read(chatRealtimeCoordinatorProvider)
        .openConversation(session.conversationId);
    if (conversation == null) {
      await ref.read(callSessionControllerProvider).decline();
      if (_activeCallRouteId == session.id) _activeCallRouteId = null;
      return;
    }
    ref
        .read(callSessionControllerProvider)
        .setPeerDisplayName(conversation.otherDisplayName);
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const CallPage(),
      ),
    );
    if (_activeCallRouteId == session.id) _activeCallRouteId = null;
  }

  void _handlePush(BuildContext context, WidgetRef ref, PushEvent event) {
    if (event.opened) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) _openPushTarget(context, ref, event);
      });
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(event.body.isEmpty ? event.title : event.body),
        action: SnackBarAction(
          label: 'Ver',
          onPressed: () => _openPushTarget(context, ref, event),
        ),
      ),
    );
  }

  Future<void> _openPushTarget(
    BuildContext context,
    WidgetRef ref,
    PushEvent event,
  ) async {
    if (event.type == 'service_request') {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ServiceRequestDetailsPage(requestId: event.targetId),
        ),
      );
      return;
    }
    if (event.type == 'chat' || event.type == 'chat_request') {
      final conversation = await ref
          .read(chatRealtimeCoordinatorProvider)
          .openConversation(event.targetId);
      if (!context.mounted) return;
      if (conversation == null) {
        _navigation.select(MainTab.conversations);
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => ChatPage(conversation: conversation)),
      );
    }
  }
}

class _ProfileErrorPage extends StatelessWidget {
  const _ProfileErrorPage({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 38,
                color: AppColors.primary,
              ),
              const SizedBox(height: 12),
              const Text(
                'Não foi possível carregar seu perfil.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: 220,
                child: AppButton(label: 'Tentar novamente', onPressed: onRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
