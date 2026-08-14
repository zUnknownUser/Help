import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/home/presentation/widgets/home_image.dart';

void main() {
  testWidgets('decodifica imagem remota no tamanho exibido', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(devicePixelRatio: 2),
          child: Center(
            child: SizedBox(
              width: 100,
              height: 50,
              child: HomeImage(
                imageUrl: 'https://example.invalid/image.jpg',
                alignment: Alignment.center,
              ),
            ),
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image).first);
    final provider = image.image as ResizeImage;
    expect(provider.width, 200);
    expect(provider.height, 100);
  });
}
