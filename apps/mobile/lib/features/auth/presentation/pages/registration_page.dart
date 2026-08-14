import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/components/app_brand.dart';
import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_text_field.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../../core/design_system/foundations/app_spacing.dart';
import '../../../profile/presentation/extensions/profile_failure_message.dart';
import '../../../profile/presentation/widgets/role_selector.dart';
import '../controllers/registration_state.dart';
import '../extensions/auth_failure_message.dart';
import '../providers/auth_providers.dart';
import '../validators/login_form_validator.dart';
import '../validators/registration_form_validator.dart';
import '../widgets/login_error_banner.dart';

class RegistrationPage extends ConsumerStatefulWidget {
  const RegistrationPage({super.key});

  @override
  ConsumerState<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends ConsumerState<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _showRoleError = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registrationControllerProvider);
    final failureMessage =
        state.authFailure?.userMessage ?? state.profileFailure?.userMessage;
    return PopScope(
      canPop: !state.isLoading && !state.accountCreated,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: const AppBrand(),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Crie sua conta',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Comece escolhendo como você quer usar o Help. Isso poderá ser alterado depois.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if (failureMessage != null) ...[
                          LoginErrorBanner(message: failureMessage),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        AppTextField(
                          fieldKey: const Key('registration_name_field'),
                          controller: _name,
                          label: 'Nome',
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                          validator: RegistrationFormValidator.displayName,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          enabled: !state.isLoading && !state.accountCreated,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          fieldKey: const Key('registration_email_field'),
                          controller: _email,
                          label: 'E-mail',
                          prefixIcon: const Icon(Icons.mail_outline_rounded),
                          validator: LoginFormValidator.email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          enabled: !state.isLoading && !state.accountCreated,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          fieldKey: const Key('registration_password_field'),
                          controller: _password,
                          label: 'Senha',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          validator: RegistrationFormValidator.password,
                          obscureText: state.obscurePassword,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.newPassword],
                          enabled: !state.isLoading && !state.accountCreated,
                          suffixIcon: IconButton(
                            onPressed: state.isLoading
                                ? null
                                : ref
                                      .read(
                                        registrationControllerProvider.notifier,
                                      )
                                      .togglePasswordVisibility,
                            icon: Icon(
                              state.obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          fieldKey: const Key(
                            'registration_confirmation_field',
                          ),
                          controller: _confirmation,
                          label: 'Confirmar senha',
                          prefixIcon: const Icon(Icons.lock_reset_rounded),
                          validator: (value) =>
                              RegistrationFormValidator.passwordConfirmation(
                                value,
                                _password.text,
                              ),
                          obscureText: state.obscurePassword,
                          textInputAction: TextInputAction.done,
                          enabled: !state.isLoading && !state.accountCreated,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const Text(
                          'Como você quer começar?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        RoleSelector(
                          selected: state.selectedRole,
                          enabled: !state.isLoading,
                          onSelected: (role) {
                            setState(() => _showRoleError = false);
                            ref
                                .read(registrationControllerProvider.notifier)
                                .selectRole(role);
                          },
                        ),
                        if (_showRoleError) ...[
                          const SizedBox(height: 6),
                          const Text(
                            'Escolha uma das opções para continuar.',
                            style: TextStyle(
                              color: AppColors.danger,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        AppButton(
                          key: const Key('registration_submit_button'),
                          label: state.accountCreated
                              ? 'Concluir perfil'
                              : 'Criar conta',
                          isLoading: state.isLoading,
                          onPressed: state.isLoading
                              ? null
                              : () => _submit(state),
                        ),
                        if (state.accountCreated && !state.isLoading) ...[
                          const SizedBox(height: 8),
                          Center(
                            child: TextButton(
                              onPressed: _cancelCreatedAccount,
                              child: const Text('Sair e voltar ao login'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _cancelCreatedAccount() async {
    await ref.read(signOutProvider)();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _submit(RegistrationState state) async {
    final roleValid = state.selectedRole != null;
    setState(() => _showRoleError = !roleValid);
    if (!roleValid || !(_formKey.currentState?.validate() ?? false)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final success = await ref
        .read(registrationControllerProvider.notifier)
        .register(
          displayName: _name.text,
          email: _email.text,
          password: _password.text,
        );
    if (success && mounted) Navigator.of(context).pop();
  }
}
