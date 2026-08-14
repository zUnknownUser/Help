import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/home/domain/entities/home_content.dart';
import 'package:help/features/home/domain/entities/home_location.dart';
import 'package:help/features/home/presentation/widgets/benefits_strip.dart';
import 'package:help/features/home/presentation/widgets/category_grid.dart';
import 'package:help/features/home/presentation/widgets/home_content_view.dart';
import 'package:help/features/home/presentation/widgets/service_section.dart';

void main() {
  testWidgets('omite seções dinâmicas sem conteúdo', (tester) async {
    const content = HomeContent(
      location: HomeLocation(address: '', availabilityLabel: ''),
      searchPlaceholder: '',
      promotions: [],
      categories: [],
      recommendedServices: [],
      benefits: [],
    );

    await tester.pumpWidget(
      const MaterialApp(home: HomeContentView(content: content)),
    );

    expect(find.byType(CategoryGrid), findsNothing);
    expect(find.byType(ServiceSection), findsNothing);
    expect(find.byType(BenefitsStrip), findsNothing);
  });
}
