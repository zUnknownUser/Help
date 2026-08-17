import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_text_field.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/entities/user_profile.dart';
import '../extensions/profile_failure_message.dart';
import '../providers/profile_providers.dart';

class AccountProfilePage extends ConsumerStatefulWidget {
  const AccountProfilePage({required this.profile, super.key});
  final UserProfile profile;

  @override
  ConsumerState<AccountProfilePage> createState() => _AccountProfilePageState();
}

class _AccountProfilePageState extends ConsumerState<AccountProfilePage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.displayName);
    _email = TextEditingController(text: widget.profile.email);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roleState = ref.watch(profileRoleControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const CircleAvatar(
            radius: 42,
            backgroundColor: AppColors.primarySoft,
            foregroundColor: AppColors.primary,
            child: Icon(Icons.person_outline_rounded, size: 38),
          ),
          const SizedBox(height: 24),
          Form(
            key: _form,
            child: AppTextField(
              controller: _name,
              label: 'Nome',
              maxLength: 80,
              textInputAction: TextInputAction.done,
              validator: (value) {
                final length = value?.trim().length ?? 0;
                return length < 2 ? 'Informe pelo menos 2 caracteres.' : null;
              },
            ),
          ),
          const SizedBox(height: 12),
          AppTextField(controller: _email, label: 'E-mail', enabled: false),
          if (roleState.failure case final failure?) ...[
            const SizedBox(height: 10),
            Text(
              failure.userMessage,
              style: const TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ],
          const SizedBox(height: 22),
          AppButton(
            label: 'Salvar alterações',
            isLoading: roleState.isLoading,
            onPressed: roleState.isLoading ? null : _save,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final success = await ref
        .read(profileRoleControllerProvider.notifier)
        .activate(role: widget.profile.activeRole, displayName: _name.text);
    if (success && mounted) Navigator.pop(context);
  }
}
