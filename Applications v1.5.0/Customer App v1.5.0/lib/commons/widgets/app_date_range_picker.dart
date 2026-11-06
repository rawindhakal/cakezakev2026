import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared date-range picker: matches the app's status-bar icon color to the
/// current theme brightness, recomputed on every rebuild off the dialog's
/// own live context so a mid-dialog system theme change updates it
/// immediately instead of only after reopening.
Future<DateTimeRange?> showAppDateRangePicker({
  required BuildContext context,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTimeRange? initialDateRange,
}) {
  return showDateRangePicker(
    context: context,
    firstDate: firstDate,
    lastDate: lastDate,
    initialDateRange: initialDateRange,
    builder: (context, child) {
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;
      final overlayStyle = isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark;
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: Theme(
          data: theme.copyWith(
            appBarTheme: theme.appBarTheme.copyWith(
              systemOverlayStyle: overlayStyle,
            ),
          ),
          child: child!,
        ),
      );
    },
  );
}
