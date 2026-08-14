import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:help/core/design_system/theme/app_theme.dart';
import 'package:help/features/provider/domain/entities/provider_workspace.dart';
import 'package:help/features/provider/presentation/widgets/provider_dashboard_view.dart';

void main() {
  testWidgets('mostra dados reais e ações principais do prestador', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ProviderDashboardView(
          workspace: _workspace,
          chatUnreadCount: 2,
          onRefresh: () async {},
          onAvailabilityChanged: (_) {},
          onAlert: (_) {},
          onCreateService: () {},
          onEditService: (_) {},
          onPublishedChanged: (_, _) {},
          onDeleteService: (_) {},
          onConversations: () {},
          onAccount: () {},
          onNotifications: () {},
        ),
      ),
    );

    expect(find.text('Olá, Luis'), findsOneWidget);
    expect(find.text('2'), findsWidgets);

    final createButton = find.byKey(
      const Key('provider_create_service_button'),
    );
    await tester.scrollUntilVisible(
      createButton,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(createButton, findsOneWidget);

    final emptyRequests = find.text('Nenhuma solicitação por enquanto');
    await tester.scrollUntilVisible(
      emptyRequests,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(emptyRequests, findsOneWidget);
  });
}

const _workspace = ProviderWorkspace(
  provider: ProviderAccount(
    id: 'provider-1',
    displayName: 'Luis',
    status: 'approved',
    active: true,
    acceptingRequests: true,
  ),
  location: ProviderLocation(),
  summary: ProviderSummary(
    totalServices: 0,
    publishedServices: 0,
    pausedServices: 0,
    pendingRequests: 0,
    unreadMessages: 2,
    unreadNotifications: 0,
  ),
  alerts: [],
  categories: [],
  services: [],
  recentRequests: [],
  notifications: [],
);
