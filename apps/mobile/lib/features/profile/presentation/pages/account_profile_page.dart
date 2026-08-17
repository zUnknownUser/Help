import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/components/app_text_field.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/entities/profile_details.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/user_role.dart';
import '../extensions/profile_failure_message.dart';
import '../providers/profile_providers.dart';
import '../widgets/profile_avatar.dart';
import 'change_email_page.dart';

class AccountProfilePage extends ConsumerStatefulWidget {
  const AccountProfilePage({required this.profile, super.key});
  final UserProfile profile;

  @override
  ConsumerState<AccountProfilePage> createState() => _AccountProfilePageState();
}

class _AccountProfilePageState extends ConsumerState<AccountProfilePage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _title;
  late final TextEditingController _bio;
  late final TextEditingController _experience;
  late double _radius;
  late String _contact;
  late String _photoVisibility;
  late String _lastSeenVisibility;
  late bool _showOnline;
  late bool _allowConversationRequests;

  bool get _isProvider => widget.profile.activeRole == UserRole.provider;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    final professional = profile.professional;
    _name = TextEditingController(text: profile.displayName);
    _phone = TextEditingController(text: profile.phone);
    _title = TextEditingController(text: professional?.title ?? '');
    _bio = TextEditingController(text: professional?.bio ?? '');
    _experience = TextEditingController(
      text: professional?.yearsExperience?.toString() ?? '',
    );
    _radius = (professional?.serviceRadiusKm ?? 10).toDouble();
    _contact = profile.preferences.contactPreference;
    _photoVisibility = profile.preferences.photoVisibility;
    _lastSeenVisibility = profile.preferences.lastSeenVisibility;
    _showOnline = profile.preferences.showOnline;
    _allowConversationRequests = profile.preferences.allowConversationRequests;
  }

  @override
  void dispose() {
    for (final controller in [_name, _phone, _title, _bio, _experience]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileEditorControllerProvider);
    final profile = ref.watch(currentProfileProvider).value ?? widget.profile;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Editar perfil')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            _ProfileIdentityCard(
              profile: profile,
              isBusy: state.isSaving,
              onAvatarTap: _pickAvatar,
            ),
            const SizedBox(height: 22),
            _titleLabel('Dados pessoais'),
            AppTextField(
              controller: _name,
              label: 'Nome',
              maxLength: 80,
              textInputAction: TextInputAction.next,
              validator: (value) => (value?.trim().length ?? 0) < 2
                  ? 'Informe pelo menos 2 caracteres.'
                  : null,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _phone,
              label: 'Telefone (opcional)',
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: _validatePhone,
            ),
            const SizedBox(height: 12),
            _EmailTile(email: profile.email, onChange: _changeEmail),
            if (_isProvider) ...[
              const SizedBox(height: 26),
              _titleLabel('Apresentação profissional'),
              AppTextField(
                controller: _title,
                label: 'Título profissional',
                hint: 'Ex.: Eletricista residencial',
                maxLength: 100,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _bio,
                label: 'Sobre seu trabalho',
                hint: 'Conte sua experiência e seus diferenciais',
                minLines: 3,
                maxLines: 5,
                maxLength: 1000,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _experience,
                label: 'Anos de experiência (opcional)',
                keyboardType: TextInputType.number,
                validator: _validateExperience,
              ),
              const SizedBox(height: 16),
              _ServiceRadius(value: _radius, onChanged: _setRadius),
              const SizedBox(height: 20),
              _PortfolioSection(
                profile: profile,
                isBusy: state.isSaving,
                onAdd: _pickPortfolio,
                onDelete: _deletePortfolio,
              ),
            ],
            const SizedBox(height: 26),
            _titleLabel('Privacidade e contato'),
            _ProfilePreferencesCard(
              contact: _contact,
              photoVisibility: _photoVisibility,
              lastSeenVisibility: _lastSeenVisibility,
              showOnline: _showOnline,
              allowConversationRequests: _allowConversationRequests,
              onContactChanged: (value) => setState(() => _contact = value),
              onPhotoChanged: (value) =>
                  setState(() => _photoVisibility = value),
              onLastSeenChanged: (value) =>
                  setState(() => _lastSeenVisibility = value),
              onShowOnlineChanged: (value) =>
                  setState(() => _showOnline = value),
              onConversationRequestsChanged: (value) =>
                  setState(() => _allowConversationRequests = value),
            ),
            if (state.failure case final failure?) ...[
              const SizedBox(height: 14),
              Text(
                failure.userMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 10, 20, 14),
        child: AppButton(
          label: 'Salvar alterações',
          isLoading: state.isSaving,
          onPressed: state.isSaving ? null : _save,
        ),
      ),
    );
  }

  Widget _titleLabel(String value) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 10),
    child: Text(
      value,
      style: const TextStyle(
        color: AppColors.primaryDark,
        fontSize: 13,
        fontWeight: FontWeight.w900,
      ),
    ),
  );

  Future<void> _pickAvatar() => _pickImage(
    (path) =>
        ref.read(profileEditorControllerProvider.notifier).uploadAvatar(path),
  );

  Future<void> _pickPortfolio() => _pickImage(
    (path) => ref
        .read(profileEditorControllerProvider.notifier)
        .uploadPortfolio(path),
  );

  Future<void> _pickImage(Future<bool> Function(String) upload) async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 86,
      maxWidth: 1800,
    );
    if (image == null || !mounted) return;
    await upload(image.path);
  }

  Future<void> _deletePortfolio(String id) async {
    await ref
        .read(profileEditorControllerProvider.notifier)
        .deletePortfolio(id);
  }

  void _setRadius(double value) => setState(() => _radius = value);

  void _changeEmail() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ChangeEmailPage(currentEmail: widget.profile.email),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final years = int.tryParse(_experience.text.trim());
    final update = ProfileUpdate(
      displayName: _name.text.trim(),
      phone: _phone.text,
      preferences: ProfilePreferences(
        contactPreference: _contact,
        photoVisibility: _photoVisibility,
        lastSeenVisibility: _lastSeenVisibility,
        showOnline: _showOnline,
        allowConversationRequests: _allowConversationRequests,
      ),
      professional: _isProvider
          ? ProfessionalProfile(
              title: _title.text.trim(),
              bio: _bio.text.trim(),
              yearsExperience: years,
              serviceRadiusKm: _radius.round(),
            )
          : null,
    );
    final success = await ref
        .read(profileEditorControllerProvider.notifier)
        .save(update);
    if (success && mounted) Navigator.pop(context);
  }
}

String? _validatePhone(String? value) {
  final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty || (digits.length >= 10 && digits.length <= 13)) {
    return null;
  }
  return 'Informe um telefone válido com DDD.';
}

String? _validateExperience(String? value) {
  if ((value ?? '').trim().isEmpty) return null;
  final years = int.tryParse(value!.trim());
  return years == null || years < 0 || years > 80
      ? 'Use um valor entre 0 e 80.'
      : null;
}

String _absoluteMediaUrl(String value) =>
    value.startsWith('http') ? value : '${AppConfig.apiBaseUrl}$value';

class _ProfileIdentityCard extends StatelessWidget {
  const _ProfileIdentityCard({
    required this.profile,
    required this.isBusy,
    required this.onAvatarTap,
  });
  final UserProfile profile;
  final bool isBusy;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.outline),
    ),
    child: Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            ProfileAvatar(
              size: 90,
              url: profile.avatarUrl,
              fallback: Image.asset('assets/icons/user_avatar.png', width: 52),
            ),
            Positioned(
              right: -4,
              bottom: -2,
              child: IconButton.filled(
                onPressed: isBusy ? null : onAvatarTap,
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          profile.displayName,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: profile.completeness.clamp(0, 100) / 100,
                minHeight: 7,
                borderRadius: BorderRadius.circular(20),
                backgroundColor: AppColors.primarySoft,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${profile.completeness}%',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 5),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Perfil completo',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ),
      ],
    ),
  );
}

class _EmailTile extends StatelessWidget {
  const _EmailTile({required this.email, required this.onChange});
  final String email;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) => ListTile(
    tileColor: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: AppColors.outline),
    ),
    leading: const Icon(
      Icons.mark_email_read_outlined,
      color: AppColors.primary,
    ),
    title: Text(email, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: const Text('E-mail verificado'),
    trailing: TextButton(onPressed: onChange, child: const Text('Trocar')),
  );
}

class _ServiceRadius extends StatelessWidget {
  const _ServiceRadius({required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: AppColors.outline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Raio de atendimento · ${value.round()} km',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        Slider(
          value: value,
          min: 1,
          max: 100,
          divisions: 99,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

class _PortfolioSection extends StatelessWidget {
  const _PortfolioSection({
    required this.profile,
    required this.isBusy,
    required this.onAdd,
    required this.onDelete,
  });
  final UserProfile profile;
  final bool isBusy;
  final VoidCallback onAdd;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Portfólio',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          TextButton.icon(
            onPressed: isBusy || profile.portfolio.length >= 12 ? null : onAdd,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Adicionar'),
          ),
        ],
      ),
      if (profile.portfolio.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppColors.outline),
          ),
          child: const Text(
            'Mostre trabalhos reais para aumentar a confiança dos clientes.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        )
      else
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: profile.portfolio.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, index) {
              final item = profile.portfolio[index];
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      _absoluteMediaUrl(item.url),
                      width: 108,
                      height: 108,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: IconButton.filledTonal(
                      visualDensity: VisualDensity.compact,
                      onPressed: isBusy ? null : () => onDelete(item.id),
                      icon: const Icon(Icons.close_rounded, size: 17),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
    ],
  );
}

class _ProfilePreferencesCard extends StatelessWidget {
  const _ProfilePreferencesCard({
    required this.contact,
    required this.photoVisibility,
    required this.lastSeenVisibility,
    required this.showOnline,
    required this.allowConversationRequests,
    required this.onContactChanged,
    required this.onPhotoChanged,
    required this.onLastSeenChanged,
    required this.onShowOnlineChanged,
    required this.onConversationRequestsChanged,
  });
  final String contact;
  final String photoVisibility;
  final String lastSeenVisibility;
  final bool showOnline;
  final bool allowConversationRequests;
  final ValueChanged<String> onContactChanged;
  final ValueChanged<String> onPhotoChanged;
  final ValueChanged<String> onLastSeenChanged;
  final ValueChanged<bool> onShowOnlineChanged;
  final ValueChanged<bool> onConversationRequestsChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: AppColors.outline),
    ),
    child: Column(
      children: [
        _select('Preferência de contato', contact, const {
          'chat': 'Chat',
          'phone': 'Telefone',
          'email': 'E-mail',
        }, onContactChanged),
        const SizedBox(height: 10),
        _select('Quem vê sua foto', photoVisibility, const {
          'everyone': 'Todos',
          'conversations': 'Meus contatos',
          'nobody': 'Ninguém',
        }, onPhotoChanged),
        const SizedBox(height: 10),
        _select('Quem vê seu visto por último', lastSeenVisibility, const {
          'everyone': 'Todos',
          'conversations': 'Meus contatos',
          'nobody': 'Ninguém',
        }, onLastSeenChanged),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mostrar quando estiver online'),
          value: showOnline,
          onChanged: onShowOnlineChanged,
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Permitir novas conversas'),
          subtitle: const Text(
            'Somente pessoas autorizadas pelo fluxo do serviço',
          ),
          value: allowConversationRequests,
          onChanged: onConversationRequestsChanged,
        ),
      ],
    ),
  );

  Widget _select(
    String label,
    String value,
    Map<String, String> options,
    ValueChanged<String> onChanged,
  ) => DropdownButtonFormField<String>(
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: options.entries
        .map(
          (entry) =>
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
        )
        .toList(growable: false),
    onChanged: (next) {
      if (next != null) onChanged(next);
    },
  );
}
