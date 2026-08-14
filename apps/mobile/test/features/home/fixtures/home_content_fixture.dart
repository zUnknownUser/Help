import 'package:help/features/home/domain/entities/home_benefit.dart';
import 'package:help/features/home/domain/entities/home_content.dart';
import 'package:help/features/home/domain/entities/home_location.dart';
import 'package:help/features/home/domain/entities/promotion.dart';
import 'package:help/features/home/domain/entities/service_category.dart';
import 'package:help/features/home/domain/entities/service_offer.dart';
import 'package:help/features/home/domain/entities/service_provider.dart';

abstract final class HomeContentFixture {
  static const content = HomeContent(
    location: HomeLocation(
      address: 'Av. Eduardo Ribeiro, 520',
      availabilityLabel: 'Serviços disponíveis na sua região',
    ),
    searchPlaceholder: 'Busque por um serviço ou profissional',
    categoriesTitle: 'Serviços populares',
    recommendationsTitle: 'Recomendados para você',
    unreadNotificationCount: 0,
    notifications: [],
    promotions: [promotion, promotion, promotion],
    categories: [
      ServiceCategory(
        id: 'home-cleaning',
        name: 'Limpeza\nresidencial',
        iconKey: 'home',
      ),
      ServiceCategory(
        id: 'air-conditioning',
        name: 'Reparo de\nar-condicionado',
        iconKey: 'ac',
      ),
      ServiceCategory(id: 'plumbing', name: 'Encanador', iconKey: 'plumbing'),
      ServiceCategory(
        id: 'electrical',
        name: 'Eletricista',
        iconKey: 'electrical',
      ),
      ServiceCategory(
        id: 'washing-machine',
        name: 'Máquina de\nlavar',
        iconKey: 'laundry',
      ),
      ServiceCategory(
        id: 'refrigerator',
        name: 'Geladeira',
        iconKey: 'refrigerator',
      ),
      ServiceCategory(
        id: 'microwave',
        name: 'Micro-ondas',
        iconKey: 'microwave',
      ),
      ServiceCategory(id: 'more', name: 'Mais\nserviços', iconKey: 'more'),
    ],
    recommendedServices: [
      ServiceOffer(
        id: 'home-cleaning',
        categoryId: 'home-cleaning',
        title: 'Limpeza residencial',
        rating: 4.8,
        reviews: 2300,
        durationMinutes: 150,
        priceCents: 7900,
        oldPriceCents: 9900,
        imageAlignment: .18,
        imageUrl: 'asset://assets/images/ac_technician.png',
        badge: 'Mais vendido',
        provider: provider,
      ),
      ServiceOffer(
        id: 'air-conditioning-repair',
        categoryId: 'air-conditioning',
        title: 'Reparo de ar-condicionado',
        rating: 4.7,
        reviews: 1800,
        durationMinutes: 60,
        priceCents: 5900,
        oldPriceCents: 7900,
        imageAlignment: .78,
        imageUrl: 'asset://assets/images/ac_technician.png',
        provider: provider,
      ),
      ServiceOffer(
        id: 'electrical-maintenance',
        categoryId: 'electrical',
        title: 'Manutenção elétrica',
        rating: 4.9,
        reviews: 940,
        durationMinutes: 90,
        priceCents: 8900,
        oldPriceCents: 10900,
        imageAlignment: .52,
        imageUrl: 'asset://assets/images/ac_technician.png',
        provider: provider,
      ),
    ],
    benefits: [
      HomeBenefit(
        id: 'verified',
        label: 'Profissionais\nverificados',
        iconKey: 'verified',
      ),
      HomeBenefit(
        id: 'pricing',
        label: 'Preços\ntransparentes',
        iconKey: 'pricing',
      ),
      HomeBenefit(
        id: 'warranty',
        label: 'Garantia de\naté 30 dias',
        iconKey: 'warranty',
      ),
      HomeBenefit(
        id: 'tracking',
        label: 'Acompanhe em\ntempo real',
        iconKey: 'location',
      ),
    ],
  );

  static const promotion = Promotion(
    id: 'air-conditioning',
    eyebrow: 'Seu ar não está gelando?',
    title: 'A gente resolve rápido.',
    imageUrl: 'asset://assets/images/ac_technician.png',
    features: [
      PromotionFeature(
        iconKey: 'fast',
        label: 'Atendimento a partir de 30 min',
      ),
      PromotionFeature(iconKey: 'verified', label: 'Profissionais verificados'),
    ],
    actions: [
      PromotionAction(
        id: 'fast-service',
        label: 'Serviço rápido',
        iconKey: 'fast',
        style: PromotionActionStyle.primary,
        type: PromotionActionType.category,
        target: 'air-conditioning',
      ),
      PromotionAction(
        id: 'schedule',
        label: 'Agendar',
        iconKey: 'calendar',
        style: PromotionActionStyle.secondary,
        type: PromotionActionType.category,
        target: 'air-conditioning',
      ),
    ],
  );

  static const provider = ServiceProvider(
    id: 'help-partner',
    name: 'Parceiro Help',
    verified: true,
  );
}
