import '../../domain/failures/profile_failure.dart';

class ProfileRoleState {
  const ProfileRoleState({this.isLoading = false, this.failure});

  final bool isLoading;
  final ProfileFailure? failure;
}
