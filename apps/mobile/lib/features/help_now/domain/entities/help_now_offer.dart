class HelpNowOffer {
  const HelpNowOffer({
    required this.id,
    required this.requestId,
    required this.categoryId,
    required this.categoryName,
    required this.note,
    required this.area,
    required this.distanceMeters,
    required this.expiresAt,
  });

  final String id;
  final String requestId;
  final String categoryId;
  final String categoryName;
  final String note;
  final String area;
  final int distanceMeters;
  final DateTime expiresAt;

  bool isExpired(DateTime now) => !expiresAt.isAfter(now);
  String get distanceLabel => distanceMeters < 1000
      ? '$distanceMeters m'
      : '${(distanceMeters / 1000).toStringAsFixed(1)} km';
}
