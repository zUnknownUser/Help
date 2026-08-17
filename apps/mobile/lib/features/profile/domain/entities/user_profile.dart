import 'user_role.dart';
import 'profile_details.dart';

enum ProviderOnboardingStatus { pending, approved, rejected }

class UserProfile {
  const UserProfile({
    required this.email,
    required this.displayName,
    required this.activeRole,
    required this.roles,
    this.providerStatus,
    this.phone = '',
    this.avatarUrl = '',
    this.preferences = const ProfilePreferences(),
    this.professional,
    this.portfolio = const [],
    this.rating = 0,
    this.reviewCount = 0,
    this.completeness = 0,
  });

  final String email;
  final String displayName;
  final UserRole activeRole;
  final List<UserRole> roles;
  final ProviderOnboardingStatus? providerStatus;
  final String phone;
  final String avatarUrl;
  final ProfilePreferences preferences;
  final ProfessionalProfile? professional;
  final List<PortfolioItem> portfolio;
  final double rating;
  final int reviewCount;
  final int completeness;

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
