import '../../../profile/domain/entities/user_role.dart';
import '../../../profile/domain/failures/profile_failure.dart';
import '../../domain/failures/auth_failure.dart';

enum RegistrationStatus { idle, loading, success, failure }

class RegistrationState {
  const RegistrationState({
    this.status = RegistrationStatus.idle,
    this.selectedRole,
    this.obscurePassword = true,
    this.accountCreated = false,
    this.authFailure,
    this.profileFailure,
  });

  final RegistrationStatus status;
  final UserRole? selectedRole;
  final bool obscurePassword;
  final bool accountCreated;
  final AuthFailure? authFailure;
  final ProfileFailure? profileFailure;

  bool get isLoading => status == RegistrationStatus.loading;

  RegistrationState copyWith({
    RegistrationStatus? status,
    UserRole? selectedRole,
    bool? obscurePassword,
    bool? accountCreated,
    AuthFailure? authFailure,
    ProfileFailure? profileFailure,
    bool clearFailures = false,
  }) => RegistrationState(
    status: status ?? this.status,
    selectedRole: selectedRole ?? this.selectedRole,
    obscurePassword: obscurePassword ?? this.obscurePassword,
    accountCreated: accountCreated ?? this.accountCreated,
    authFailure: clearFailures ? null : authFailure ?? this.authFailure,
    profileFailure: clearFailures
        ? null
        : profileFailure ?? this.profileFailure,
  );
}
