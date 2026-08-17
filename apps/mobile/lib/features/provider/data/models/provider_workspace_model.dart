import '../../domain/entities/provider_workspace.dart';
import 'provider_json.dart';
import 'provider_service_model.dart';

class ProviderWorkspaceModel {
  const ProviderWorkspaceModel(this.value);

  factory ProviderWorkspaceModel.fromEnvelope(Map<String, dynamic> envelope) {
    final json = ProviderJson.map(envelope['data'], 'data');
    final provider = ProviderJson.map(json['provider'], 'provider');
    final location = ProviderJson.map(json['location'], 'location');
    final summary = ProviderJson.map(json['summary'], 'summary');
    return ProviderWorkspaceModel(
      ProviderWorkspace(
        provider: ProviderAccount(
          id: ProviderJson.string(provider, 'id'),
          displayName: ProviderJson.string(provider, 'display_name'),
          status: ProviderJson.string(provider, 'status'),
          active: ProviderJson.boolean(provider, 'active'),
          acceptingRequests: ProviderJson.boolean(
            provider,
            'accepting_requests',
          ),
        ),
        location: ProviderLocation(
          address: ProviderJson.string(location, 'address'),
          latitude: (location['latitude'] as num?)?.toDouble(),
          longitude: (location['longitude'] as num?)?.toDouble(),
        ),
        summary: ProviderSummary(
          totalServices: ProviderJson.integer(summary, 'total_services'),
          publishedServices: ProviderJson.integer(
            summary,
            'published_services',
          ),
          pausedServices: ProviderJson.integer(summary, 'paused_services'),
          pendingRequests: ProviderJson.integer(summary, 'pending_requests'),
          unreadMessages: ProviderJson.integer(summary, 'unread_messages'),
          unreadNotifications: ProviderJson.integer(
            summary,
            'unread_notifications',
          ),
        ),
        alerts: ProviderJson.maps(json['alerts'], 'alerts')
            .map(
              (item) => ProviderAlert(
                kind: ProviderJson.string(item, 'kind'),
                title: ProviderJson.string(item, 'title'),
                message: ProviderJson.string(item, 'message'),
              ),
            )
            .toList(growable: false),
        categories: ProviderJson.maps(json['categories'], 'categories')
            .map(
              (item) => ProviderCategory(
                id: ProviderJson.string(item, 'id'),
                name: ProviderJson.string(item, 'name'),
                iconKey: ProviderJson.string(item, 'icon_key'),
              ),
            )
            .toList(growable: false),
        services: ProviderJson.maps(json['services'], 'services')
            .map(ProviderServiceModel.fromJson)
            .map((model) => model.toEntity())
            .toList(growable: false),
        recentRequests: ProviderJson.maps(
          json['recent_requests'],
          'recent_requests',
        ).map(_request).toList(growable: false),
        notifications: ProviderJson.maps(json['notifications'], 'notifications')
            .map(
              (item) => ProviderNotification(
                id: ProviderJson.string(item, 'id'),
                title: ProviderJson.string(item, 'title'),
                body: ProviderJson.string(item, 'body'),
                kind: item['kind'] as String? ?? '',
                data: _notificationData(item['data']),
                read: ProviderJson.boolean(item, 'read'),
                createdAt: DateTime.parse(
                  ProviderJson.string(item, 'created_at'),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  final ProviderWorkspace value;

  ProviderWorkspace toEntity() => value;

  static ProviderRequest _request(Map<String, dynamic> json) => ProviderRequest(
    id: ProviderJson.string(json, 'id'),
    serviceTitle: ProviderJson.string(json, 'service_title'),
    customerName: ProviderJson.string(json, 'customer_name'),
    status: ProviderJson.string(json, 'status'),
    note: ProviderJson.string(json, 'note'),
    quotedPriceCents: ProviderJson.integer(json, 'quoted_price_cents'),
    address: ProviderJson.string(json, 'address'),
    createdAt: DateTime.parse(ProviderJson.string(json, 'created_at')),
    scheduledFor: switch (json['scheduled_for']) {
      final String value => DateTime.parse(value),
      _ => null,
    },
  );
}

Map<String, String> _notificationData(Object? value) {
  if (value == null) return const {};
  final map = ProviderJson.map(value, 'data');
  return map.map((key, value) {
    if (value is! String) {
      throw const FormatException('notification data must contain strings');
    }
    return MapEntry(key, value);
  });
}
