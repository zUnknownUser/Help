import 'package:flutter/material.dart';

class HomeImage extends StatelessWidget {
  const HomeImage({required this.imageUrl, required this.alignment, super.key});

  final String? imageUrl;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    if (imageUrl case final url? when url.isNotEmpty) {
      if (url.startsWith('asset://')) {
        return Image.asset(
          url.substring('asset://'.length),
          fit: BoxFit.cover,
          alignment: alignment,
        );
      }
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
            errorBuilder: (_, _, _) => const _ImagePlaceholder(),
          );
        },
      );
    }
    return const _ImagePlaceholder();
  }

  int? _cachePixels(double logicalSize, double pixelRatio) {
    if (!logicalSize.isFinite || logicalSize <= 0) return null;
    return (logicalSize * pixelRatio).ceil();
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFEAF5EE),
      child: Center(
        child: Icon(
          Icons.home_repair_service_outlined,
          color: Color(0xFF4F9E6C),
          size: 34,
        ),
      ),
    );
  }
}
