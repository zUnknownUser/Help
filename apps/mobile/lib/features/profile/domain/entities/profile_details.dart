class ProfilePreferences {
  const ProfilePreferences({
    this.contactPreference = 'chat',
    this.photoVisibility = 'everyone',
    this.lastSeenVisibility = 'everyone',
    this.showOnline = true,
    this.allowConversationRequests = true,
  });

  final String contactPreference;
  final String photoVisibility;
  final String lastSeenVisibility;
  final bool showOnline;
  final bool allowConversationRequests;
}

class ProfessionalProfile {
  const ProfessionalProfile({
    this.title = '',
    this.bio = '',
    this.yearsExperience,
    this.serviceRadiusKm = 10,
  });

  final String title;
  final String bio;
  final int? yearsExperience;
  final int serviceRadiusKm;
}

class PortfolioItem {
  const PortfolioItem({required this.id, required this.url, this.caption = ''});

  final String id;
  final String url;
  final String caption;
}

class ProfileUpdate {
  const ProfileUpdate({
    required this.displayName,
    required this.phone,
    required this.preferences,
    this.professional,
  });

  final String displayName;
  final String phone;
  final ProfilePreferences preferences;
  final ProfessionalProfile? professional;
}
