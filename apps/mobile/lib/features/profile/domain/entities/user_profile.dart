import 'user_role.dart';

enum ProviderOnboardingStatus { pending, approved, rejected }

class UserProfile {
  const UserProfile({
    required this.email,
    required this.displayName,
    required this.activeRole,
    required this.roles,
    this.providerStatus,
  });

  final String email;
  final String displayName;
  final UserRole activeRole;
  final List<UserRole> roles;
  final ProviderOnboardingStatus? providerStatus;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          email == other.email &&
          displayName == other.displayName &&
          activeRole == other.activeRole &&
          providerStatus == other.providerStatus &&
          _sameRoles(roles, other.roles);

  @override
  int get hashCode => Object.hash(
    email,
    displayName,
    activeRole,
    providerStatus,
    Object.hashAll(roles),
  );
}

bool _sameRoles(List<UserRole> left, List<UserRole> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
