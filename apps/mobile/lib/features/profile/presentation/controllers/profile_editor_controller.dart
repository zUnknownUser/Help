import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/profile_details.dart';
import '../../data/providers/profile_data_providers.dart';
import '../providers/profile_providers.dart';
import 'profile_editor_state.dart';

class ProfileEditorController extends Notifier<ProfileEditorState> {
  @override
  ProfileEditorState build() => const ProfileEditorState();

  Future<bool> save(ProfileUpdate update) => _run(() async {
    final result = await ref.read(profileRepositoryProvider).update(update);
    return result.fold(
      onSuccess: (profile) {
        ref.read(currentProfileProvider.notifier).replace(profile);
        return true;
      },
      onFailure: _fail,
    );
  });

  Future<bool> uploadAvatar(String path) => _run(() async {
    final result = await ref.read(profileRepositoryProvider).uploadAvatar(path);
    final success = result.fold(onSuccess: (_) => true, onFailure: _fail);
    if (success) {
      await ref.read(currentProfileProvider.notifier).retry();
    }
    return success;
  });

  Future<bool> uploadPortfolio(String path) => _run(() async {
    final result = await ref
        .read(profileRepositoryProvider)
        .uploadPortfolio(path);
    final success = result.fold(onSuccess: (_) => true, onFailure: _fail);
    if (success) {
      await ref.read(currentProfileProvider.notifier).retry();
    }
    return success;
  });

  Future<bool> deletePortfolio(String id) => _run(() async {
    final result = await ref
        .read(profileRepositoryProvider)
        .deletePortfolio(id);
    final success = result.fold(onSuccess: (_) => true, onFailure: _fail);
    if (success) {
      await ref.read(currentProfileProvider.notifier).retry();
    }
    return success;
  });

  Future<bool> _run(Future<bool> Function() operation) async {
    if (state.isSaving) return false;
    state = const ProfileEditorState(isSaving: true);
    final success = await operation();
    if (ref.mounted && success) state = const ProfileEditorState();
    return success;
  }

  bool _fail(dynamic failure) {
    if (ref.mounted) state = ProfileEditorState(failure: failure);
    return false;
  }
}
