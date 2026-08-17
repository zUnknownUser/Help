class HomeNotification {
  const HomeNotification({
    required this.id,
    required this.title,
    required this.body,
    this.kind = '',
    this.data = const {},
    required this.read,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String kind;
  final Map<String, String> data;
  final bool read;
  final DateTime createdAt;
}
