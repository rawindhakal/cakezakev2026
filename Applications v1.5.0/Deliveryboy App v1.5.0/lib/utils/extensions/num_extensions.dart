/// Safely parses any JSON numeric value (String/int/double/null) to double.
double toSafeDouble(dynamic value, [double fallback = 0.0]) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

/// Safely coerces any JSON value (bool/num/String/null) to bool, or null.
bool? toSafeBoolOrNull(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final s = value.toString().toLowerCase();
  if (s == 'true' || s == '1') return true;
  if (s == 'false' || s == '0') return false;
  return null;
}

/// Safely parses any JSON numeric value (String/int/double/null) to double, or null.
double? toSafeDoubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

/// Safely parses any JSON numeric value (String/int/double/null) to int.
int toSafeInt(dynamic value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? fallback;
}

/// Safely parses any JSON numeric value (String/int/double/null) to int, or null.
int? toSafeIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

/// Safely stringifies any JSON value (String/int/double/bool/null) to String.
String toSafeString(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  return value.toString();
}

/// Safely coerces any JSON value (bool/num/String/null) to bool.
bool toSafeBool(dynamic value, [bool fallback = false]) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final s = value.toString().toLowerCase();
  if (s == 'true' || s == '1') return true;
  if (s == 'false' || s == '0') return false;
  return fallback;
}

/// Safely parses a JSON list into a typed list, tolerating null/non-list input.
List<T> toSafeList<T>(dynamic value, T Function(dynamic) fromJson) {
  if (value is! List) return <T>[];
  return value.map(fromJson).toList();
}

extension NumFormatting on num {
  /// Fixes to [decimals] places, then strips a trailing `.0` / `.00` (and
  /// the dot itself) so whole-number amounts never show fake precision.
  String trimmedFixed([int decimals = 2]) {
    var value = toStringAsFixed(decimals);
    if (value.contains('.')) {
      value = value.replaceFirst(RegExp(r'\.?0+$'), '');
    }
    return value;
  }
}
