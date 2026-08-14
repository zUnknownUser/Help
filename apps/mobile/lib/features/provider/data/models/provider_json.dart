abstract final class ProviderJson {
  static Map<String, dynamic> map(Object? value, String field) {
    if (value is! Map) throw FormatException('$field must be an object');
    return Map<String, dynamic>.from(value);
  }

  static List<Map<String, dynamic>> maps(Object? value, String field) {
    if (value is! List) throw FormatException('$field must be a list');
    return value.map((item) => map(item, field)).toList(growable: false);
  }

  static String string(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value is! String) throw FormatException('$field must be a string');
    return value;
  }

  static int integer(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value is! num) throw FormatException('$field must be a number');
    return value.toInt();
  }

  static double decimal(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value is! num) throw FormatException('$field must be a number');
    return value.toDouble();
  }

  static bool boolean(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value is! bool) throw FormatException('$field must be a boolean');
    return value;
  }
}
