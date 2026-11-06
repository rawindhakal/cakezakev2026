import 'package:flutter/material.dart';

final class AppColors {
  AppColors._();

  // SVGs designed with this placeholder primary color — AppSvgColorMapper
  // swaps it for the server's runtime primary color.
  static const Color svgPrimaryPlaceholder = Color(0xFFFE3C5E);

  static const Color lightGray = Color(0xFFE5E7EB);

  // Primary color palette
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

  // Category
  static const Color categoryTileBg = Color(0xFFE5F3F3);

  // Misc
  static const Color star = Color(0xFFFFC107);
  static const Color divider = Color(0xFFEEEEEE);
  static const Color dividerDark = Color(0xFF424242);
  static const Color border = Color(0xFFE0E0E0);
  static const Color borderDark = Color(0xFF424242);
  static const Color shadow = Color(0x14000000);
  static const Color iconLight = Color(0xFF757575);
  static const Color iconDark = Color(0xFFB0B0B0);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Colors.transparent;
  static const Color white70 = Color(0xB3FFFFFF);
  static const Color black87 = Color(0xDD000000);
  static const Color black54 = Color(0x8A000000);
  static const Color black26 = Color(0x42000000);
  static const Color black12 = Color(0x1F000000);
  static const Color grey = Color(0xFF9E9E9E);
  static const Color greyLight = Color(0xFFEEEEEE);
  static const Color red = Color(0xFFF44336);
  static const Color green = Color(0xFF4CAF50);
  static const Color orange = Color(0xFFFF9800);

  // Spin wheel — bespoke "prize wheel" promo palette (cream/crimson/gold),
  // not part of the general app theme. Kept here (not as local consts in
  // the widget) so every hardcoded color in the app has one source.
  static const Color spinWheelCream = Color(0xFFFBF0DA);
  static const Color spinWheelCrimson = Color(0xFFC1272D);
  static const Color spinWheelCrimsonDark = Color(0xFF8E1319);
  static const Color spinWheelGold = Color(0xFFF2C572);
  static const Color spinWheelConfettiBlue = Color(0xFF29B6F6);
  static const Color spinWheelStudHighlight = Color(0xFFD8D8D8);

  // Spin wheel — dialog chrome (background glow, scrim, title fills).
  static const Color spinWheelDialogBgTop = Color(0xFF050508);
  static const Color spinWheelDialogBgBottom = Color(0xFF050308);
  static const Color spinWheelResultScrim = Color(0xB3000000);
  static const Color spinWheelTitleBottomFillStart = Color(0xFFFFF6D6);
  static const Color spinWheelTitleBottomFillEnd = Color(0xFFFFD873);

  // Spin wheel — board/tray purple base and SPIN button gold base (runtime
  // re-themeable via campaign API; these are the design's default bases).
  static const Color spinWheelPurpleDefaultBase = Color(0xFF5B3BD2);
  static const Color spinWheelButtonGoldDefaultBase = Color(0xFFF7B32B);

  // Spin wheel — balance chip (coin + glowing pill).
  static const Color spinWheelChipGlow = Color(0x55FF8A1F);
  static const Color spinWheelChipPillBorder = Color(0xFFE8782A);
  static const Color spinWheelCoinShadow = Color(0x66000000);
  static const Color spinWheelCoinRimHi = Color(0xFFFFE27A);
  static const Color spinWheelCoinRimMid = Color(0xFFF5A623);
  static const Color spinWheelCoinRimLow = Color(0xFFC9740A);
  static const Color spinWheelCoinBorder = Color(0xFFFFF0B0);
  static const Color spinWheelCoinInnerBorder = Color(0x66A0500A);
  static const Color spinWheelCoinSymbol = Color(0xFFB85A05);

  // Spin wheel — board / title / result-card overlays.
  static const Color spinWheelBoardRimGlow = Color(0x99FFFFFF);
  static const Color spinWheelBoardHubShine = Color(0xCCFFFFFF);
  static const Color spinWheelTitleShadow = Color(0x99000000);
  static const Color spinWheelResultCardShadow = Color(0x66000000);
  static const Color spinWheelTicketLabel = Color(0xFFFFC93C);
  static const Color spinWheelTicketLabelGlow = Color(0x88FFB300);

  // Spin wheel — legacy wheel-fallback palette (used only when the campaign
  // API sends no per-segment colors).
  static const Color spinWheelFallbackHub = Color(0xFF3B4CE0);
  static const Color spinWheelGrooveGold = Color(0xFF5A2A00);
  static const List<Color> spinWheelSegmentFallback = [
    Color(0xFFF5203A), // red
    Color(0xFFFF7A12), // orange
    Color(0xFFFFE818), // yellow
    Color(0xFF2FCF2A), // green
    Color(0xFF22F0C8), // mint
    Color(0xFF17B8E8), // cyan
    Color(0xFF8CCBFA), // light blue
    Color(0xFF1F4FF0), // royal blue
    Color(0xFF2196F3), // sky blue
    Color(0xFF7A2CFA), // indigo
    Color(0xFFB57CF5), // lilac
    Color(0xFFF53CC8), // pink
  ];
  static const List<Color> spinWheelHubGoldGradient = [
    Color(0xFFFFE066),
    Color(0xFFFFB300),
    Color(0xFFFF9500),
    Color(0xFFE86A00),
  ];
  static const List<Color> spinWheelGoldRim = [
    Color(0xFFFFE066),
    Color(0xFFFFB300),
    Color(0xFFE07B00),
  ];
  static const Color spinWheelHubGoldStart = Color(0xFFE07B00);
  static const Color spinWheelHubGoldEnd = Color(0xFFFFD54F);
  static const Color spinWheelPointerGoldEnd = Color(0xFFFFE066);
  static const Color spinWheelPointerBlueStart = Color(0xFF2F6BFF);
  static const Color spinWheelPointerBlueEnd = Color(0xFF0A2FC0);
  static const Color spinWheelCenterTeal = Color(0xFF3DE8E0);
}
