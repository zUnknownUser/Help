import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/user_profile.dart';
import '../../domain/failures/profile_failure.dart';
import '../providers/profile_providers.dart';

class ProfileController extends AsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() => _load();

  Future<void> retry() async {
    state = const AsyncLoading();
    final next = await AsyncValue.guard(_load);
    if (ref.mounted) state = next;
  }

  void replace(UserProfile profile) => state = AsyncData(profile);

  Future<UserProfile> _load() async {
    final result = await ref.read(getCurrentProfileProvider)();
    return result.fold(
      onSuccess: (profile) => profile,
      onFailure: (failure) => throw ProfilePresentationException(failure),
    );
  }
}

class ProfilePresentationException implements Exception {
  const ProfilePresentationException(this.failure);

  final ProfileFailure failure;
}
