enum UserRole {
  customer,
  provider;

  String get value => name;

  static UserRole parse(String value) => switch (value) {
    'customer' => customer,
    'provider' => provider,
    _ => throw FormatException('Unknown user role: $value'),
  };
}
