import '../../domain/entities/user_role.dart';
import '../../domain/failures/profile_failure.dart';

class ProfileSetupState {
  const ProfileSetupState({this.role, this.isLoading = false, this.failure});

  final UserRole? role;
  final bool isLoading;
  final ProfileFailure? failure;

  ProfileSetupState copyWith({
    UserRole? role,
    bool? isLoading,
    ProfileFailure? failure,
    bool clearFailure = false,
  }) => ProfileSetupState(
    role: role ?? this.role,
    isLoading: isLoading ?? this.isLoading,
    failure: clearFailure ? null : failure ?? this.failure,
  );
}
