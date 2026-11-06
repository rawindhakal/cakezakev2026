import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:intl/intl.dart';

/// PHP-style date/time token -> intl [DateFormat] pattern.
/// Covers the tokens the `settings/country_setting` api sends in
/// `date_format` / `time_format` (e.g. "d/m/Y", "h:i A", "d M Y", "H:i").
const Map<String, String> _kPhpToIntlTokens = {
  'd': 'dd',
  'j': 'd',
  'D': 'EEE',
  'l': 'EEEE',
  'm': 'MM',
  'n': 'M',
  'M': 'MMM',
  'F': 'MMMM',
  'Y': 'yyyy',
  'y': 'yy',
  'H': 'HH',
  'G': 'H',
  'h': 'hh',
  'g': 'h',
  'i': 'mm',
  's': 'ss',
  'A': 'a',
  'a': 'a',
};

/// Converts a PHP-style format string (e.g. "d/m/Y") to an intl [DateFormat]
/// pattern (e.g. "dd/MM/yyyy"). Unknown letters are escaped as literals so
/// they don't get misread as intl pattern symbols.
String _phpFormatToIntlPattern(String phpFormat) {
  final buffer = StringBuffer();
  for (final char in phpFormat.split('')) {
    final mapped = _kPhpToIntlTokens[char];
    if (mapped != null) {
      buffer.write(mapped);
    } else if (RegExp(r'[a-zA-Z]').hasMatch(char)) {
      buffer.write("'$char'");
    } else {
      buffer.write(char);
    }
  }
  return buffer.toString();
}

/// Formats dates/times using the `date_format` / `time_format` strings the
/// `settings/country_setting` api returns (cached in [SettingsHiveBox] so
/// they survive across the session without refetching).
class AppDateFormatter {
  AppDateFormatter._();

  /// Matches a trailing timezone designator: "Z" or "+05:30" / "-0530".
  static final RegExp _kTzSuffix = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');

  /// Parses an api date/time value (string or [DateTime]) to local time,
  /// reinterpreting timezone-less wall-clock strings as server UTC. Returns
  /// null if [input] can't be parsed.
  static DateTime? parse(dynamic input) => _parse(input);

  static DateTime? _parse(dynamic input) {
    if (input == null) return null;
    if (input is DateTime) return input.isUtc ? input.toLocal() : input;
    if (input is String) {
      final raw = input.trim();
      if (raw.isEmpty || raw == 'null') return null;
      final parsed = DateTime.tryParse(raw);
      if (parsed == null) return null;
      if (_kTzSuffix.hasMatch(raw)) return parsed.toLocal();
      // Api sends wall-clock strings with no timezone marker (e.g.
      // "2026-01-15 10:30:00"), which is the server's UTC time — Dart
      // parses that as if it were already local, so it must be reinterpreted
      // as UTC before converting, otherwise it never shifts to device time.
      return DateTime.utc(
        parsed.year,
        parsed.month,
        parsed.day,
        parsed.hour,
        parsed.minute,
        parsed.second,
        parsed.millisecond,
      ).toLocal();
    }
    return null;
  }

  /// Formats [input] (a [DateTime] or api date string) using the stored
  /// `date_format`. Returns [input] as-is (stringified) if it can't be parsed.
  static String formatDate(dynamic input) {
    final date = _parse(input);
    if (date == null) return input?.toString() ?? '';
    final pattern = _phpFormatToIntlPattern(
      SettingsHiveBox.instance.dateFormat,
    );
    return DateFormat(pattern).format(date);
  }

  /// Formats [input] using the stored `time_format`.
  static String formatTime(dynamic input) {
    final date = _parse(input);
    if (date == null) return input?.toString() ?? '';
    final phpFormat = SettingsHiveBox.instance.timeFormat;
    final pattern = _phpFormatToIntlPattern(phpFormat);
    var formatted = DateFormat(pattern).format(date);
    // PHP's lowercase "a" (am/pm) has no direct intl equivalent — intl's
    // "a" always yields upper-case AM/PM, so lower-case it back if requested.
    if (phpFormat.contains('a') && !phpFormat.contains('A')) {
      formatted = formatted.replaceAll('AM', 'am').replaceAll('PM', 'pm');
    }
    return formatted;
  }

  /// Combines [formatDate] and [formatTime] — e.g. "15/01/2026 10:30 AM".
  static String formatDateTime(dynamic input) {
    final date = _parse(input);
    if (date == null) return input?.toString() ?? '';
    return '${formatDate(date)} ${formatTime(date)}';
  }
}
