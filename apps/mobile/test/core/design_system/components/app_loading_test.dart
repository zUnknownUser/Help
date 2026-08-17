import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:help/core/design_system/components/app_loading.dart';
import 'package:help/core/design_system/foundations/app_colors.dart';

void main() {
  testWidgets('loading de tela comunica contexto e preserva a marca', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppLoadingView(message: 'Carregando conversas…')),
      ),
    );

    expect(find.text('Carregando conversas…'), findsOneWidget);
    expect(find.byIcon(Icons.handyman_rounded), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Carregando conversas…'), findsWidgets);
    semantics.dispose();
  });

  testWidgets('loading inline aceita tamanho e cor do contexto', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: AppProgressIndicator(
            size: 18,
            color: AppColors.danger,
            semanticsLabel: 'Salvando',
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(CircularProgressIndicator)),
      const Size.square(18),
    );
    final progress = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(progress.color, AppColors.danger);
  });

  testWidgets('loading bloqueante acompanha somente a ação aguardada', (
    tester,
  ) async {
    final completion = Completer<String>();
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox();
          },
        ),
      ),
    );

    final result = runWithAppLoading(
      context,
      message: 'Abrindo conversa…',
      action: () => completion.future,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Abrindo conversa…'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);

    completion.complete('ok');
    await tester.pumpAndSettle();
    expect(await result, 'ok');
    expect(find.text('Abrindo conversa…'), findsNothing);
  });
}
