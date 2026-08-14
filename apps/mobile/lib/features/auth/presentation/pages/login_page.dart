import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/components/app_brand.dart';
import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_text_field.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../../core/design_system/foundations/app_spacing.dart';
import '../controllers/auth_form_state.dart';
import '../extensions/auth_failure_message.dart';
import '../providers/auth_providers.dart';
import '../validators/login_form_validator.dart';
import '../widgets/login_error_banner.dart';
import '../widgets/login_hero.dart';
import '../widgets/login_social_section.dart';
import 'password_reset_page.dart';
import 'registration_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AppBrand(),
                          const SizedBox(height: AppSpacing.lg),
                          const LoginHero(),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'Bem-vindo ao Help',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          const Text(
                            'Entre para encontrar profissionais de confiança e cuidar do que importa.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          if (formState.failure case final failure?) ...[
                            LoginErrorBanner(message: failure.userMessage),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          AppTextField(
                            fieldKey: const Key('login_email_field'),
                            controller: _emailController,
                            label: 'E-mail',
                            hint: 'voce@email.com',
                            prefixIcon: const Icon(Icons.mail_outline_rounded),
                            validator: LoginFormValidator.email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            enabled: !formState.isLoading,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            fieldKey: const Key('login_password_field'),
                            controller: _passwordController,
                            label: 'Senha',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            validator: LoginFormValidator.password,
                            obscureText: formState.obscurePassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            enabled: !formState.isLoading,
                            onFieldSubmitted: (_) => _submitEmail(formState),
                            suffixIcon: IconButton(
                              key: const Key('login_password_visibility'),
                              tooltip: formState.obscurePassword
                                  ? 'Mostrar senha'
                                  : 'Ocultar senha',
                              onPressed: formState.isLoading
                                  ? null
                                  : ref
                                        .read(authControllerProvider.notifier)
                                        .togglePasswordVisibility,
                              icon: Icon(
                                formState.obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              key: const Key('forgot_password_button'),
                              onPressed: formState.isLoading
                                  ? null
                                  : () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const PasswordResetPage(),
                                      ),
                                    ),
                              child: const Text('Esqueci minha senha'),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AppButton(
                            key: const Key('login_submit_button'),
                            label: 'Entrar',
                            isLoading: formState.isLoading,
                            onPressed: formState.isLoading
                                ? null
                                : () => _submitEmail(formState),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Ainda não tem conta?',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              TextButton(
                                key: const Key('create_account_button'),
                                onPressed: formState.isLoading
                                    ? null
                                    : () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              const RegistrationPage(),
                                        ),
                                      ),
                                child: const Text('Criar conta'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LoginSocialSection(
                            isLoading: formState.isLoading,
                            onGooglePressed: ref
                                .read(authControllerProvider.notifier)
                                .signInWithGoogle,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _submitEmail(AuthFormState formState) {
    if (formState.isLoading || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    ref
        .read(authControllerProvider.notifier)
        .signInWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
  }
}
