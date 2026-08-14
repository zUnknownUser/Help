import 'package:flutter/material.dart';

import '../../domain/entities/promotion.dart';
import 'home_image.dart';
import 'promo_banner_elements.dart';

class PromoBanner extends StatelessWidget {
  const PromoBanner({required this.promotion, super.key});

  final Promotion promotion;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.85,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            HomeImage(
              imageUrl: promotion.imageUrl,
              alignment: Alignment.centerRight,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xF2174D38),
                    Color(0xC9174D38),
                    Color(0x19174D38),
                    Colors.transparent,
                  ],
                  stops: [0, .38, .68, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 15, 12, 11),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: .78,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 260,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            promotion.eyebrow,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            promotion.title,
                            style: const TextStyle(
                              fontSize: 22,
                              height: 1.08,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...promotion.features
                              .take(2)
                              .expand(
                                (feature) => [
                                  PromoFeatureLine(feature: feature),
                                  const SizedBox(height: 4),
                                ],
                              ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: _actionButtons(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _actionButtons() {
    final widgets = <Widget>[];
    for (final action in promotion.actions.take(2)) {
      if (widgets.isNotEmpty) widgets.add(const SizedBox(width: 7));
      widgets.add(PromoActionButton(action: action, onTap: () {}));
    }
    return widgets;
  }
}
