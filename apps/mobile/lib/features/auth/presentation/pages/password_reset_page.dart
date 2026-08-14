import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/components/app_brand.dart';
import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_text_field.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../../core/design_system/foundations/app_radius.dart';
import '../../../../core/design_system/foundations/app_spacing.dart';
import '../controllers/password_reset_state.dart';
import '../extensions/auth_failure_message.dart';
import '../providers/auth_providers.dart';
import '../validators/login_form_validator.dart';
import '../widgets/login_error_banner.dart';

class PasswordResetPage extends ConsumerStatefulWidget {
  const PasswordResetPage({super.key});

  @override
  ConsumerState<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends ConsumerState<PasswordResetPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(passwordResetControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Voltar',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: state.status == PasswordResetStatus.success
                  ? _SuccessContent(onBack: () => Navigator.maybePop(context))
                  : Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AppBrand(),
                          const SizedBox(height: AppSpacing.xl),
                          const _ResetIcon(),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'Esqueceu sua senha?',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          const Text(
                            'Informe o e-mail da sua conta. Enviaremos um link seguro para você criar uma nova senha.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          if (state.failure case final failure?) ...[
                            LoginErrorBanner(
                              message: failure.passwordResetMessage,
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          AppTextField(
                            fieldKey: const Key('password_reset_email_field'),
                            controller: _emailController,
                            label: 'E-mail',
                            hint: 'voce@email.com',
                            prefixIcon: const Icon(Icons.mail_outline_rounded),
                            validator: LoginFormValidator.email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.email],
                            enabled: !state.isLoading,
                            onFieldSubmitted: (_) => _submit(state),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppButton(
                            key: const Key('password_reset_submit_button'),
                            label: 'Enviar link de recuperação',
                            isLoading: state.isLoading,
                            onPressed: state.isLoading
                                ? null
                                : () => _submit(state),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit(PasswordResetState state) {
    if (state.isLoading || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    ref
        .read(passwordResetControllerProvider.notifier)
        .submit(_emailController.text);
  }
}

class _ResetIcon extends StatelessWidget {
  const _ResetIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: const Icon(
        Icons.lock_reset_rounded,
        size: 38,
        color: AppColors.primaryDark,
      ),
    );
  }
}

class _SuccessContent extends StatelessWidget {
  const _SuccessContent({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppBrand(),
        const SizedBox(height: AppSpacing.xxl),
        const _ResetIcon(),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Confira seu e-mail',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Se existir uma conta para este e-mail, você receberá as instruções de recuperação em instantes.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(label: 'Voltar para entrar', onPressed: onBack),
      ],
    );
  }
}
