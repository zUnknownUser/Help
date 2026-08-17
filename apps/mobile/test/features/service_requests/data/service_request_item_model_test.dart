import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/service_requests/data/models/service_request_item_model.dart';
import 'package:help/features/service_requests/domain/entities/service_request_item.dart';

void main() {
  test('maps lifecycle contract and server actions', () {
    final item = ServiceRequestItemModel.fromJson({
      'id': 'request-1',
      'client_request_id': 'client-1',
      'service_id': 'service-1',
      'service_title': 'Limpeza',
      'provider_user_id': 'provider-user',
      'provider_name': 'Luis',
      'customer_user_id': 'customer-user',
      'customer_name': 'Ana',
      'viewer_role': 'provider',
      'status': 'pending',
      'status_reason': '',
      'version': 0,
      'available_actions': ['accepted', 'rejected'],
      'note': '',
      'scheduled_for': '2026-08-17T15:00:00Z',
      'quoted_price_cents': 15000,
      'address': {'label': 'Casa', 'formatted_address': 'Rua A, 10'},
      'created_at': '2026-08-16T12:00:00Z',
      'updated_at': '2026-08-16T12:00:00Z',
    }).entity;

    expect(item.viewerRole, RequestViewerRole.provider);
    expect(item.availableActions, {
      ServiceRequestStatus.accepted,
      ServiceRequestStatus.rejected,
    });
    expect(item.counterpartName, 'Ana');
  });
}
