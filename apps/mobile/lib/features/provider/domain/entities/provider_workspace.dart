import 'provider_service.dart';

class ProviderWorkspace {
  const ProviderWorkspace({
    required this.provider,
    required this.location,
    required this.summary,
    required this.alerts,
    required this.categories,
    required this.services,
    required this.recentRequests,
    required this.notifications,
  });

  final ProviderAccount provider;
  final ProviderLocation location;
  final ProviderSummary summary;
  final List<ProviderAlert> alerts;
  final List<ProviderCategory> categories;
  final List<ProviderService> services;
  final List<ProviderRequest> recentRequests;
  final List<ProviderNotification> notifications;

  ProviderWorkspace copyWith({
    ProviderAccount? provider,
    ProviderSummary? summary,
    List<ProviderAlert>? alerts,
    List<ProviderService>? services,
  }) => ProviderWorkspace(
    provider: provider ?? this.provider,
    location: location,
    summary: summary ?? this.summary,
    alerts: alerts ?? this.alerts,
    categories: categories,
    services: services ?? this.services,
    recentRequests: recentRequests,
    notifications: notifications,
  );
}

class ProviderAccount {
  const ProviderAccount({
    required this.id,
    required this.displayName,
    required this.status,
    required this.active,
    required this.acceptingRequests,
  });

  final String id;
  final String displayName;
  final String status;
  final bool active;
  final bool acceptingRequests;

  ProviderAccount copyWith({bool? acceptingRequests}) => ProviderAccount(
    id: id,
    displayName: displayName,
    status: status,
    active: active,
    acceptingRequests: acceptingRequests ?? this.acceptingRequests,
  );
}

class ProviderLocation {
  const ProviderLocation({this.address = '', this.latitude, this.longitude});

  final String address;
  final double? latitude;
  final double? longitude;

  bool get configured => latitude != null && longitude != null;
}

class ProviderSummary {
  const ProviderSummary({
    required this.totalServices,
    required this.publishedServices,
    required this.pausedServices,
    required this.pendingRequests,
    required this.unreadMessages,
    required this.unreadNotifications,
  });

  final int totalServices;
  final int publishedServices;
  final int pausedServices;
  final int pendingRequests;
  final int unreadMessages;
  final int unreadNotifications;

  ProviderSummary copyWith({
    int? totalServices,
    int? publishedServices,
    int? pausedServices,
  }) => ProviderSummary(
    totalServices: totalServices ?? this.totalServices,
    publishedServices: publishedServices ?? this.publishedServices,
    pausedServices: pausedServices ?? this.pausedServices,
    pendingRequests: pendingRequests,
    unreadMessages: unreadMessages,
    unreadNotifications: unreadNotifications,
  );
}

class ProviderAlert {
  const ProviderAlert({
    required this.kind,
    required this.title,
    required this.message,
  });
  final String kind;
  final String title;
  final String message;
}

class ProviderCategory {
  const ProviderCategory({
    required this.id,
    required this.name,
    required this.iconKey,
  });
  final String id;
  final String name;
  final String iconKey;
}

class ProviderRequest {
  const ProviderRequest({
    required this.id,
    required this.serviceTitle,
    required this.customerName,
    required this.status,
    required this.note,
    required this.createdAt,
    this.scheduledFor,
  });
  final String id;
  final String serviceTitle;
  final String customerName;
  final String status;
  final String note;
  final DateTime createdAt;
  final DateTime? scheduledFor;
}

class ProviderNotification {
  const ProviderNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
  });
  final String id;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;
}
