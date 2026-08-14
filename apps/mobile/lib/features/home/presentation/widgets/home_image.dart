import 'package:flutter/material.dart';

class HomeImage extends StatelessWidget {
  const HomeImage({required this.imageUrl, required this.alignment, super.key});

  static const fallbackAsset = 'assets/images/ac_technician.png';

  final String? imageUrl;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    if (imageUrl case final url? when url.isNotEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final pixelRatio = MediaQuery.devicePixelRatioOf(context);
          return Image.network(
            url,
            fit: BoxFit.cover,
            alignment: alignment,
            gaplessPlayback: true,
            cacheWidth: _cachePixels(constraints.maxWidth, pixelRatio),
            cacheHeight: _cachePixels(constraints.maxHeight, pixelRatio),
            errorBuilder: (_, _, _) => _fallback(),
          );
        },
      );
    }
    return _fallback();
  }

  Widget _fallback() =>
      Image.asset(fallbackAsset, fit: BoxFit.cover, alignment: alignment);

  int? _cachePixels(double logicalSize, double pixelRatio) {
    if (!logicalSize.isFinite || logicalSize <= 0) return null;
    return (logicalSize * pixelRatio).ceil();
  }
}
