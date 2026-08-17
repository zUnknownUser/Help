import 'package:flutter/material.dart';

import '../../domain/entities/service_offer.dart';
import 'section_title.dart';
import 'service_card.dart';

class ServiceSection extends StatelessWidget {
  const ServiceSection({
    required this.title,
    required this.offers,
    required this.onOfferTap,
    super.key,
  });

  final String title;
  final List<ServiceOffer> offers;
  final ValueChanged<ServiceOffer> onOfferTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: SectionTitle(title: title),
        ),
        SizedBox(
          height: 237,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: offers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 11),
            itemBuilder: (context, index) => ServiceCard(
              offer: offers[index],
              onTap: () => onOfferTap(offers[index]),
            ),
          ),
        ),
      ],
    );
  }
}
