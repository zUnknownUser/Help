import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:help/core/design_system/components/app_text_field.dart';

void main() {
  testWidgets('supports contextual helper text without polluting the label', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppTextField(
            controller: controller,
            label: 'Telefone',
            helperText: 'Você pode informar depois.',
          ),
        ),
      ),
    );

    expect(find.text('Telefone'), findsOneWidget);
    expect(find.text('Você pode informar depois.'), findsOneWidget);
    expect(find.textContaining('(opcional)'), findsNothing);
  });
}
