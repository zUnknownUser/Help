import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/components/app_brand.dart';
import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_text_field.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/validators/registration_form_validator.dart';
import '../../../auth/presentation/widgets/login_error_banner.dart';
import '../extensions/profile_failure_message.dart';
import '../providers/profile_providers.dart';
import '../widgets/role_selector.dart';

class ProfileSetupPage extends ConsumerStatefulWidget {
  const ProfileSetupPage({this.initialDisplayName, super.key});

  final String? initialDisplayName;

  @override
  ConsumerState<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends ConsumerState<ProfileSetupPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  bool _showRoleError = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialDisplayName);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileSetupControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppBrand(),
                    const SizedBox(height: 28),
                    Text(
                      'Complete seu perfil',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Só falta dizer como você quer começar no Help.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (state.failure case final failure?) ...[
                      LoginErrorBanner(message: failure.userMessage),
                      const SizedBox(height: 14),
                    ],
                    AppTextField(
                      fieldKey: const Key('profile_setup_name_field'),
                      controller: _name,
                      label: 'Nome',
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      validator: RegistrationFormValidator.displayName,
                      enabled: !state.isLoading,
                    ),
                    const SizedBox(height: 18),
                    RoleSelector(
                      selected: state.role,
                      enabled: !state.isLoading,
                      onSelected: (role) {
                        setState(() => _showRoleError = false);
                        ref
                            .read(profileSetupControllerProvider.notifier)
                            .selectRole(role);
                      },
                    ),
                    if (_showRoleError) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Escolha uma das opções para continuar.',
                        style: TextStyle(color: AppColors.danger, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 22),
                    AppButton(
                      key: const Key('profile_setup_submit_button'),
                      label: 'Continuar',
                      isLoading: state.isLoading,
                      onPressed: state.isLoading ? null : _submit,
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: state.isLoading
                            ? null
                            : () => ref.read(signOutProvider)(),
                        child: const Text('Sair'),
                      ),
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

  Future<void> _submit() async {
    final state = ref.read(profileSetupControllerProvider);
    setState(() => _showRoleError = state.role == null);
    if (state.role == null || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await ref.read(profileSetupControllerProvider.notifier).save(_name.text);
  }
}
