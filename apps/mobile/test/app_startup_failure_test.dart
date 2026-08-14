import 'package:flutter_test/flutter_test.dart';
import 'package:help/app.dart';

void main() {
  testWidgets('mostra uma tela útil quando o Firebase não inicializa', (
    tester,
  ) async {
    await tester.pumpWidget(const HelpStartupFailureApp());

    expect(find.text('Não foi possível iniciar o Help.'), findsOneWidget);
    expect(find.textContaining('abra o aplicativo novamente'), findsOneWidget);
  });
}
