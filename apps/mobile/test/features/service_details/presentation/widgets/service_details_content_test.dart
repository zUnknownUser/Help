import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/home/domain/entities/service_offer.dart';
import 'package:help/features/home/domain/entities/service_provider.dart';
import 'package:help/features/service_details/domain/entities/service_details.dart';
import 'package:help/features/service_details/presentation/widgets/service_details_content.dart';

void main() {
  testWidgets('mostra dados reais e encaminha definição de endereço', (
    tester,
  ) async {
    var addressTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ServiceDetailsContent(
            details: _details(address: null, canRequest: false),
            onRequest: null,
            onChat: () {},
            onAddress: () => addressTaps++,
          ),
        ),
      ),
    );

    expect(find.text('Limpeza residencial'), findsOneWidget);
    expect(find.text('R\$ 159'), findsOneWidget);
    expect(find.text('Definir endereço'), findsOneWidget);
    await tester.tap(find.text('Definir endereço'));
    expect(addressTaps, 1);
  });

  testWidgets('habilita solicitação somente com checkout autorizado', (
    tester,
  ) async {
    var requests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ServiceDetailsContent(
            details: _details(
              address: const ServiceRequestAddress(
                label: 'Casa',
                formattedAddress: 'Rua A, 10',
                latitude: -3.08,
                longitude: -59.97,
              ),
              canRequest: true,
            ),
            onRequest: () => requests++,
            onChat: () {},
            onAddress: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Solicitar serviço'));
    expect(requests, 1);
  });
}

ServiceDetails _details({
  required ServiceRequestAddress? address,
  required bool canRequest,
}) => ServiceDetails(
  offer: const ServiceOffer(
    id: 'service-1',
    title: 'Limpeza residencial',
    categoryId: '',
    rating: 4.8,
    reviews: 10,
    durationMinutes: 90,
    priceCents: 15900,
    oldPriceCents: 15900,
    imageAlignment: 0,
    provider: ServiceProvider(id: 'provider-1', name: 'Luis', verified: true),
  ),
  description: 'Limpeza completa',
  providerUserId: 'provider-user',
  serviceArea: 'Manaus - AM',
  requestAddress: address,
  canRequest: canRequest,
  requestBlockedReason: address == null ? 'address_required' : '',
);
