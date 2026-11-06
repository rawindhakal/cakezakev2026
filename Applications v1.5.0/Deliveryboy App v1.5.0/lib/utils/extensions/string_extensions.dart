extension NullableStringExt on String? {
  /// Returns true when the value is non-null, non-empty, and not the literal string 'null'.
  bool get isNotNullOrEmpty =>
      this != null && this!.isNotEmpty && this != 'null';
}

extension StringCaseExt on String {
  /// Uppercases only the first character, lowercasing the rest.
  String get capitalize =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
}

extension DateTimeExt on DateTime {
  String toApiDateString() =>
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}
