import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_text_field.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../controllers/email_change_controller.dart';
import '../validators/email_change_validator.dart';

class ChangeEmailPage extends ConsumerStatefulWidget {
  const ChangeEmailPage({required this.currentEmail, super.key});
  final String currentEmail;

  @override
  ConsumerState<ChangeEmailPage> createState() => _ChangeEmailPageState();
}

class _ChangeEmailPageState extends ConsumerState<ChangeEmailPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(emailChangeControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Trocar e-mail')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (state.verificationSent)
            _VerificationSent(email: _email.text)
          else ...[
            const Text(
              'Proteja o acesso à sua conta',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Seu e-mail atual é ${widget.currentEmail}. Ele continuará válido até você confirmar o novo endereço.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Form(
              key: _form,
              child: Column(
                children: [
                  AppTextField(
                    controller: _email,
                    label: 'Novo e-mail',
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.newUsername],
                    validator: (value) => validateEmailChange(
                      value,
                      currentEmail: widget.currentEmail,
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _password,
                    label: 'Senha atual',
                    hint: 'Para contas com e-mail e senha',
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Se você entrou com Google, deixe a senha vazia: pediremos a confirmação pela sua conta Google.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (state.message case final message?) ...[
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 24),
          AppButton(
            label: state.verificationSent
                ? 'Já confirmei o link'
                : 'Enviar confirmação',
            isLoading: state.isLoading,
            onPressed: state.isLoading ? null : _submit,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final controller = ref.read(emailChangeControllerProvider.notifier);
    final sent = ref.read(emailChangeControllerProvider).verificationSent;
    if (sent) {
      final success = await controller.confirm(_email.text);
      if (success && mounted) Navigator.pop(context);
      return;
    }
    if (!(_form.currentState?.validate() ?? false)) return;
    await controller.request(_email.text.trim(), _password.text);
  }
}

class _VerificationSent extends StatelessWidget {
  const _VerificationSent({required this.email});
  final String email;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Image.asset('assets/animations/email.gif', height: 136),
      const SizedBox(height: 18),
      const Text(
        'Confira seu novo e-mail',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      Text(
        'Enviamos a confirmação para $email. Depois de abrir o link, volte aqui para concluir.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    ],
  );
}
