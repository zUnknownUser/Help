import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/help_now/domain/entities/help_now_request.dart';
import 'package:help/features/help_now/presentation/widgets/help_now_status_visual.dart';

void main() {
  testWidgets('uses the animated radar only while searching', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HelpNowStatusVisual(status: HelpNowStatus.searching),
      ),
    );

    expect(find.byType(Image), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: HelpNowStatusVisual(status: HelpNowStatus.assigned),
      ),
    );
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });
}
