import 'package:flutter/material.dart';

final class AppColors {
  AppColors._();

  // SVGs designed with this placeholder primary color — AppSvgColorMapper
  // swaps it for the server's runtime primary color.
  static const Color svgPrimaryPlaceholder = Color(0xFFFE3C5E);

  static const Color lightGray = Color(0xFFE5E7EB);

  // Primary green palette
  static const Color primary = Color(0xFFFE3C5E);
  static const Color primaryDark = Color(0xFFFE3C5E);
  static const Color primaryLight = Color(0xFFFE3C5E);
  static const Color primaryContainer = Color(0xFFE8F5E9);

  // Backgrounds
  static const Color backgroundLight = Color(0xFFF5F6FA);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF2C2C2C);

  // Text
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF616161);
  static const Color textHint = Color(0xFFBDBDBD);
  static const Color textPrimaryDark = Color(0xFFF5F5F5);
  static const Color textSecondaryDark = Color(0xFFB0B0B0);

  // Status / chips
  static const Color cod = Color(0xFFE65100);
  static const Color codBg = Color(0xFFFFF3E0);
  static const Color prepaid = Color(0xFF1565C0);
  static const Color prepaidBg = Color(0xFFE3F2FD);
  static const Color assigned = Color(0xFF6A1B9A);
  static const Color assignedBg = Color(0xFFF3E5F5);
  static const Color completed = Color(0xFF2E7D32);
  static const Color completedBg = Color(0xFFE8F5E9);
  static const Color pending = Color(0xFFF57F17);
  static const Color pendingBg = Color(0xFFFFF8E1);
  static const Color cancelled = Color(0xFFC62828);
  static const Color cancelledBg = Color(0xFFFFEBEE);
  static const Color returnRed = Color(0xFFD32F2F);
  static const Color returnBg = Color(0xFFFFEBEE);

  // Feedback
  static const Color success = Color(0xFF2E7D32);
  static const Color error = Color(0xFFC62828);
  static const Color warning = Color(0xFFF57F17);
  static const Color info = Color(0xFF0288D1);

  // Additional status colors
  static const Color delivered = Color(0xFF00695C);
  static const Color deliveredBg = Color(0xFFE0F2F1);
  static const Color neutralBg = Color(0xFFF5F5F5);
  static const Color onPrimaryAccent = Color(0xFF69F0AE);
  static const Color primarySurface = Color(0xFFC8E6C9);

  // Misc
  static const Color star = Color(0xFFFFC107);
  static const Color divider = Color(0xFFEEEEEE);
  static const Color dividerDark = Color(0xFF424242);
  static const Color border = Color(0xFFE0E0E0);
  static const Color borderDark = Color(0xFF424242);
  static const Color shadow = Color(0x14000000);
  static const Color shadowMedium = Color(0x28000000);
  static const Color shadowDark = Color(0x42000000);
  static const Color iconLight = Color(0xFF757575);
  static const Color iconDark = Color(0xFFB0B0B0);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Colors.transparent;

  // Grayscale ramp — SVG-baked match keys for
  // [AppSvgColorMapper.substitute]; not display output, so not theme-sourced.
  static const Color textStrong = Color(0xFF111111);
  static const Color iconBorder = Color(0xFFE1E1E1);
  static const Color divider2 = Color(0xFFEDEDED);

  // Bottom nav bar icon roles — feed ColorScheme.onSecondary/surfaceDim/scrim
  // in AppTheme, read via context.cs.
  static const Color bottomNavInactiveBlackLight = Color(0xFF333333);
  static const Color bottomNavInactiveBlackDark = Color(0xFFC8C8C8);
  static const Color bottomNavLightGrayLight = Color(0xFFE1E1E1);
  static const Color bottomNavLightGrayDark = Color(0xFF5C5C5C);
  static const Color bottomNavActiveBlackLight = Color(0xFF444444);
}
