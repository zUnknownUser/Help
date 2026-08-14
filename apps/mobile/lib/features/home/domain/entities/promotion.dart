enum PromotionActionStyle { primary, secondary }

enum PromotionActionType { category, allServices }

class Promotion {
  const Promotion({
    required this.id,
    required this.eyebrow,
    required this.title,
    required this.features,
    required this.actions,
    this.imageUrl,
  });

  final String id;
  final String eyebrow;
  final String title;
  final String? imageUrl;
  final List<PromotionFeature> features;
  final List<PromotionAction> actions;
}

class PromotionFeature {
  const PromotionFeature({required this.iconKey, required this.label});

  final String iconKey;
  final String label;
}

class PromotionAction {
  const PromotionAction({
    required this.id,
    required this.label,
    required this.iconKey,
    required this.style,
    required this.type,
    this.target,
  });

  final String id;
  final String label;
  final String iconKey;
  final PromotionActionStyle style;
  final PromotionActionType type;
  final String? target;
}
