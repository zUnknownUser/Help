abstract final class JsonReader {
  static Map<String, dynamic> map(Object? value, String field) {
    if (value case final Map<String, dynamic> result) return result;
    throw FormatException('$field must be an object');
  }

  static List<Map<String, dynamic>> maps(Object? value, String field) {
    if (value is! List) throw FormatException('$field must be an array');
    return value.map((item) => map(item, field)).toList(growable: false);
  }

  static List<String> strings(Object? value, String field) {
    if (value is! List || value.any((item) => item is! String)) {
      throw FormatException('$field must be a string array');
    }
    return value.cast<String>();
  }

  static String string(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value is String) return value;
    throw FormatException('$field must be a string');
  }

  static int integer(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value is int) return value;
    throw FormatException('$field must be an integer');
  }

  static double decimal(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value is num) return value.toDouble();
    throw FormatException('$field must be a number');
  }

  static bool boolean(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value is bool) return value;
    throw FormatException('$field must be a boolean');
  }

  static String? optionalString(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value == null || value == '') return null;
    if (value is String) return value;
    throw FormatException('$field must be a string');
  }

  static double? optionalDecimal(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value == null) return null;
    if (value is num) return value.toDouble();
    throw FormatException('$field must be a number');
  }
}
