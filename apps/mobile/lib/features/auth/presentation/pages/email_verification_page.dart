import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/components/app_brand.dart';
import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/entities/auth_user.dart';
import '../controllers/email_verification_state.dart';
import '../extensions/auth_failure_message.dart';
import '../providers/auth_providers.dart';
import '../widgets/login_error_banner.dart';

class EmailVerificationPage extends ConsumerStatefulWidget {
  const EmailVerificationPage({required this.user, super.key});

  final AuthUser user;

  @override
  ConsumerState<EmailVerificationPage> createState() =>
      _EmailVerificationPageState();
}

class _EmailVerificationPageState extends ConsumerState<EmailVerificationPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      ref.read(emailVerificationControllerProvider.notifier).send,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(emailVerificationControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  const AppBrand(),
                  const SizedBox(height: 32),
                  Container(
                    width: 82,
                    height: 82,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primarySoft,
                    ),
                    child: const Icon(
                      Icons.mark_email_unread_outlined,
                      size: 38,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Confirme seu e-mail',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Enviamos um link para ${widget.user.email}. Abra o e-mail e confirme sua conta para continuar.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (state.failure case final failure?) ...[
                    LoginErrorBanner(message: failure.userMessage),
                    const SizedBox(height: 16),
                  ] else if (state.status == EmailVerificationStatus.sent) ...[
                    const Text(
                      'Link enviado. Confira também sua caixa de spam.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  AppButton(
                    key: const Key('verification_confirmed_button'),
                    label: 'Já confirmei',
                    isLoading: state.status == EmailVerificationStatus.checking,
                    onPressed: state.isBusy ? null : _check,
                  ),
                  const SizedBox(height: 10),
                  AppButton(
                    key: const Key('verification_resend_button'),
                    label: 'Reenviar e-mail',
                    variant: AppButtonVariant.outlined,
                    isLoading: state.status == EmailVerificationStatus.sending,
                    onPressed: state.isBusy
                        ? null
                        : ref
                              .read(
                                emailVerificationControllerProvider.notifier,
                              )
                              .send,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const Key('verification_sign_out_button'),
                    onPressed: state.isBusy
                        ? null
                        : () => ref.read(signOutProvider)(),
                    child: const Text('Sair e usar outra conta'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _check() async {
    final verified = await ref
        .read(emailVerificationControllerProvider.notifier)
        .check();
    if (!mounted) return;
    if (verified) {
      ref.invalidate(authStateProvider);
      return;
    }
    if (ref.read(emailVerificationControllerProvider).failure == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A confirmação ainda não apareceu. Aguarde alguns segundos e tente novamente.',
          ),
        ),
      );
    }
  }
}
