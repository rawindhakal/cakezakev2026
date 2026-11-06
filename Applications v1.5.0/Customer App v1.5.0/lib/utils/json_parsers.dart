/// Safely parses a JSON value into a double, whether the API sent it as a
/// String ("12.50"), an int, or a double — [double.tryParse] alone would
/// crash at runtime on a non-String value.
double parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0.0;
}

/// Like [parseDouble] but keeps "the API did not send this" distinct from 0.
double? parseDoubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

/// Parses a JSON value into an int whether it arrived as `5`, `"5"` or `5.0`.
/// Returns null when absent or unparseable, so `int?` fields keep their
/// "not sent" meaning instead of silently becoming 0.
int? parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  final raw = value.toString();
  return int.tryParse(raw) ?? double.tryParse(raw)?.toInt();
}

/// Parses a JSON value into a num, whether it arrived as a number or a String.
num? parseNum(dynamic value) {
  if (value == null) return null;
  if (value is num) return value;
  return num.tryParse(value.toString());
}

/// Parses a JSON bool the API may send as `true`, `1`, `"1"` or `"true"` —
/// assigning those straight into a `bool?` field throws a TypeError.
bool? parseBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  switch (value.toString().toLowerCase()) {
    case 'true':
    case '1':
      return true;
    case 'false':
    case '0':
      return false;
  }
  return null;
}

/// Stringifies a JSON value without turning a missing one into the literal
/// text "null", and without throwing when the API sends a number for a
/// `String?` field.
String? parseString(dynamic value) => value?.toString();
