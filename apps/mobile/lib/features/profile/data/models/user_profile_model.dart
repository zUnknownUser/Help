import '../../domain/entities/user_profile.dart';
import '../../domain/entities/user_role.dart';

class UserProfileModel {
  const UserProfileModel({
    required this.email,
    required this.displayName,
    required this.activeRole,
    required this.roles,
    this.providerStatus,
  });

  factory UserProfileModel.fromEnvelope(Map<String, dynamic> envelope) {
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Missing profile data');
    }
    final roles = data['roles'];
    if (roles is! List) throw const FormatException('Invalid profile roles');
    return UserProfileModel(
      email: data['email'] as String,
      displayName: data['display_name'] as String,
      activeRole: UserRole.parse(data['active_role'] as String),
      roles: roles
          .map((role) => UserRole.parse(role as String))
          .toList(growable: false),
      providerStatus: _parseProviderStatus(data['provider_status']),
    );
  }

  final String email;
  final String displayName;
  final UserRole activeRole;
  final List<UserRole> roles;
  final ProviderOnboardingStatus? providerStatus;

  UserProfile toEntity() => UserProfile(
    email: email,
    displayName: displayName,
    activeRole: activeRole,
    roles: List.unmodifiable(roles),
    providerStatus: providerStatus,
  );
}

ProviderOnboardingStatus? _parseProviderStatus(Object? value) =>
    switch (value) {
      null => null,
      'pending' => ProviderOnboardingStatus.pending,
      'approved' => ProviderOnboardingStatus.approved,
      'rejected' => ProviderOnboardingStatus.rejected,
      _ => throw FormatException('Unknown provider status: $value'),
    };
