/// Helpers tolerantes para parsear respuestas JSON del backend.
class JsonParse {
  JsonParse._();

  static String? stringOrNull(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text == 'null' || text == 'None') return null;
    return text;
  }

  static String string(dynamic value, {String fallback = ''}) {
    return stringOrNull(value) ?? fallback;
  }

  static int intValue(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.round();
    final text = value.toString().trim();
    if (text.isEmpty) return fallback;
    return int.tryParse(text) ?? double.tryParse(text)?.round() ?? fallback;
  }

  static double doubleValue(dynamic value, {double fallback = 0}) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    final text = value.toString().trim();
    if (text.isEmpty) return fallback;
    return double.tryParse(text) ?? fallback;
  }

  static bool boolValue(dynamic value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    final text = value.toString().trim().toLowerCase();
    if (text == 'true' || text == '1' || text == 'yes' || text == 'si') {
      return true;
    }
    if (text == 'false' || text == '0' || text == 'no') {
      return false;
    }
    return fallback;
  }

  static Map<String, dynamic> map(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  static List<T> list<T>(
    dynamic value,
    T Function(Map<String, dynamic> json) mapper,
  ) {
    if (value is! List) return <T>[];
    final result = <T>[];
    for (final item in value) {
      if (item is Map) {
        result.add(mapper(Map<String, dynamic>.from(item)));
      }
    }
    return result;
  }

  static DateTime? dateTime(dynamic value) {
    final text = stringOrNull(value);
    if (text == null) return null;

    final parsed = DateTime.tryParse(text);
    if (parsed != null) return parsed;

    final dateOnly = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
    if (dateOnly != null) {
      return DateTime(
        int.parse(dateOnly.group(1)!),
        int.parse(dateOnly.group(2)!),
        int.parse(dateOnly.group(3)!),
      );
    }
    return null;
  }

  static int? intOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    final text = value.toString().trim();
    if (text.isEmpty || text == 'null' || text == 'None') return null;
    return int.tryParse(text) ?? double.tryParse(text)?.round();
  }

  static double? doubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    final text = value.toString().trim();
    if (text.isEmpty || text == 'null' || text == 'None') return null;
    return double.tryParse(text);
  }
}
