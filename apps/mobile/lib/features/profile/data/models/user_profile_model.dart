import '../../domain/entities/user_profile.dart';
import '../../domain/entities/profile_details.dart';
import '../../domain/entities/user_role.dart';

class UserProfileModel {
  const UserProfileModel({
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
      phone: data['phone'] as String? ?? '',
      avatarUrl: data['avatar_url'] as String? ?? '',
      preferences: ProfilePreferences(
        contactPreference: data['contact_preference'] as String? ?? 'chat',
        photoVisibility: data['photo_visibility'] as String? ?? 'everyone',
        lastSeenVisibility:
            data['last_seen_visibility'] as String? ?? 'everyone',
        showOnline: data['show_online'] as bool? ?? true,
        allowConversationRequests:
            data['allow_conversation_requests'] as bool? ?? true,
      ),
      professional: _professional(data['professional']),
      portfolio: _portfolio(data['portfolio']),
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: data['review_count'] as int? ?? 0,
      completeness: data['completeness'] as int? ?? 0,
    );
  }

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

  UserProfile toEntity() => UserProfile(
    email: email,
    displayName: displayName,
    activeRole: activeRole,
    roles: List.unmodifiable(roles),
    providerStatus: providerStatus,
    phone: phone,
    avatarUrl: avatarUrl,
    preferences: preferences,
    professional: professional,
    portfolio: List.unmodifiable(portfolio),
    rating: rating,
    reviewCount: reviewCount,
    completeness: completeness,
  );
}

ProfessionalProfile? _professional(Object? value) {
  if (value is! Map<String, dynamic>) return null;
  return ProfessionalProfile(
    title: value['title'] as String? ?? '',
    bio: value['bio'] as String? ?? '',
    yearsExperience: value['years_experience'] as int?,
    serviceRadiusKm: value['service_radius_km'] as int? ?? 10,
  );
}

List<PortfolioItem> _portfolio(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map<String, dynamic>>()
      .map((item) {
        return PortfolioItem(
          id: item['id'] as String,
          url: item['url'] as String,
          caption: item['caption'] as String? ?? '',
        );
      })
      .toList(growable: false);
}

ProviderOnboardingStatus? _parseProviderStatus(Object? value) =>
    switch (value) {
      null => null,
      'pending' => ProviderOnboardingStatus.pending,
      'approved' => ProviderOnboardingStatus.approved,
      'rejected' => ProviderOnboardingStatus.rejected,
      _ => throw FormatException('Unknown provider status: $value'),
    };
