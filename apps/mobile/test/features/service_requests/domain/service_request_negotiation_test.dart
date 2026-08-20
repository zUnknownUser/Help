import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/service_requests/domain/entities/service_request_negotiation.dart';

void main() {
  test('quote draft calculates additions and discounts in integer cents', () {
    const draft = ServiceQuoteDraft(
      items: [
        ServiceQuoteItemDraft(
          kind: ServiceQuoteItemKind.labor,
          description: 'Mão de obra',
          amountCents: 20000,
        ),
        ServiceQuoteItemDraft(
          kind: ServiceQuoteItemKind.material,
          description: 'Material',
          amountCents: 7500,
        ),
        ServiceQuoteItemDraft(
          kind: ServiceQuoteItemKind.discount,
          description: 'Desconto',
          amountCents: 2500,
        ),
      ],
    );

    expect(draft.totalCents, 25000);
  });

  test('wire enums reject unknown values instead of silently degrading', () {
    expect(
      () => ServiceQuoteItemKind.parse('fee'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ServiceQuoteStatus.parse('paid'),
      throwsA(isA<FormatException>()),
    );
  });
}
