class ServiceReview {
  const ServiceReview({
    required this.id,
    required this.reviewerRole,
    required this.rating,
    required this.comment,
  });
  final String id;
  final String reviewerRole;
  final int rating;
  final String comment;
}
