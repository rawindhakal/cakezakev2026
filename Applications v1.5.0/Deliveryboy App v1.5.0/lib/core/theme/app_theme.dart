import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'package:deliveryboy/core/configs/app_config.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';

/// ColorScheme has a fixed Material role set with no slot for app-specific
/// brand/status colors, so this app repurposes otherwise-unused roles to
/// carry them (avoids hardcoded `AppColors.*` reads at call sites — use
/// `context.cs.<role>` instead). Role -> actual meaning:
/// tertiary=cod, secondaryContainer=prepaid, tertiaryContainer=assigned,
/// onSecondaryContainer=completed/success, errorContainer=pending/warning,
/// onErrorContainer=cancelled, onSecondaryFixed=returnRed, inversePrimary=info,
/// primaryFixedDim=delivered, surfaceContainerLowest=neutralBg,
/// onTertiary=onPrimaryAccent, onTertiaryContainer=primarySurface,
/// onPrimaryFixedVariant=star, onSecondary=bottomNavInactiveBlack,
/// surfaceDim=bottomNavLightGray, tertiaryFixed=bottomNavActiveBlack,
/// surfaceBright=bottomNavConstant. "Bg" variants (codBg, pendingBg, ...)
/// derive from the base role via `.withValues(alpha: 0.12)` at call sites.
/// (`onError`, `scrim`, `inverseSurface`/`onInverseSurface` are already used
/// for their real Material meaning elsewhere; `surfaceTint` is NOT free even
/// though nothing here calls it explicitly — Material3 `Card`/`Dialog`/
/// `BottomSheet` read it automatically for the elevation tint overlay, so
/// repurposing it tints every elevated surface app-wide. Do not repurpose
/// any of these.)
final class AppTheme {
  AppTheme._();

  static const _buttonRadius = AppRadius.r10;

  /// Right-to-left slide push with edge swipe-back gesture on every platform.
  static const _pageTransitionsTheme = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    },
  );

  static int _ch(double v) => v.round().clamp(0, 255);

  static Color _darken(Color c) => Color.fromARGB(
    255,
    _ch((c.r * 255.0) * 0.7),
    _ch((c.g * 255.0) * 0.7),
    _ch((c.b * 255.0) * 0.7),
  );

  static Color _container(Color c) => Color.fromARGB(
    255,
    _ch(c.r * 255.0 + (255 - c.r * 255.0) * 0.88),
    _ch(c.g * 255.0 + (255 - c.g * 255.0) * 0.88),
    _ch(c.b * 255.0 + (255 - c.b * 255.0) * 0.88),
  );

  static Color _lighten(Color c) => Color.fromARGB(
    255,
    _ch(c.r * 255.0 + (255 - c.r * 255.0) * 0.3),
    _ch(c.g * 255.0 + (255 - c.g * 255.0) * 0.3),
    _ch(c.b * 255.0 + (255 - c.b * 255.0) * 0.3),
  );

  static ThemeData lightTheme([Color? primaryColor]) {
    final primary = primaryColor ?? AppColors.primary;
    final primaryDark = _darken(primary);
    final primaryLight = _lighten(primary);
    final primaryContainer = _container(primary);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: AppConfig.fontFamily,
      primaryColor: primary,
      pageTransitionsTheme: _pageTransitionsTheme,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      colorScheme: ColorScheme.light(
        primary: primary,
        primaryContainer: primaryContainer,
        secondary: primaryLight,
        error: AppColors.error,
        surface: AppColors.surfaceLight,
        onPrimary: AppColors.white,
        onPrimaryContainer: primaryDark,
        onSurface: AppColors.textPrimary,
        onSurfaceVariant: AppColors.textSecondary,
        outline: AppColors.border,
        outlineVariant: AppColors.divider,
        surfaceContainerLow: AppColors.backgroundLight,
        surfaceContainerHigh: const Color(0xFFF0F0F0),
        surfaceContainerHighest: const Color(0xFFEAEAEA),
        shadow: AppColors.shadow,
        // Repurposed roles below carry brand/status meaning, not their
        // Material name — see AppTheme doc comment for the full map.
        tertiary: AppColors.cod,
        secondaryContainer: AppColors.prepaid,
        tertiaryContainer: AppColors.assigned,
        onSecondaryContainer: AppColors.completed,
        errorContainer: AppColors.pending,
        onErrorContainer: AppColors.cancelled,
        onSecondaryFixed: AppColors.returnRed,
        inversePrimary: AppColors.info,
        primaryFixedDim: AppColors.delivered,
        surfaceContainerLowest: AppColors.neutralBg,
        onTertiary: AppColors.onPrimaryAccent,
        onTertiaryContainer: AppColors.primarySurface,
        onPrimaryFixedVariant: AppColors.star,
        onSecondary: AppColors.bottomNavInactiveBlackLight,
        surfaceDim: AppColors.bottomNavLightGrayLight,
        tertiaryFixed: AppColors.bottomNavActiveBlackLight,
        surfaceBright: AppColors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardLight,
        elevation: 2,
        shadowColor: AppColors.shadow,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.r12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return primary.withValues(alpha: 0.6);
            }
            return primary;
          }),
          foregroundColor: WidgetStateProperty.all(AppColors.white),
          overlayColor: WidgetStateProperty.all(
            AppColors.white.withValues(alpha: 0.12),
          ),
          minimumSize: WidgetStateProperty.all(const Size(double.infinity, 52)),
          shape: WidgetStateProperty.all(
            const RoundedRectangleBorder(borderRadius: _buttonRadius),
          ),
          elevation: WidgetStateProperty.all(0),
          shadowColor: WidgetStateProperty.all(AppColors.transparent),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(double.infinity, 52),
          side: BorderSide(color: primary, width: 1.5),
          shape: const RoundedRectangleBorder(borderRadius: _buttonRadius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsetsDirectional.symmetric(
          horizontal: ThemeConstants.paddingL,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.r10,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.r10,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.r10,
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.r10,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.r10,
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
        displayMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        displaySmall: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        headlineLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
        headlineMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: primary,
        indicatorSize: TabBarIndicatorSize.tab,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedItemColor: primary,
        unselectedItemColor: AppColors.iconLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return null;
        }),
      ),
    );
  }

  static ThemeData darkTheme([Color? primaryColor]) {
    final primary = primaryColor ?? AppColors.primaryLight;
    final primaryDark = _darken(primary);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: AppConfig.fontFamily,
      primaryColor: primary,
      pageTransitionsTheme: _pageTransitionsTheme,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      colorScheme: ColorScheme.dark(
        primary: primary,
        primaryContainer: primaryDark,
        secondary: primary,
        error: AppColors.error,
        surface: AppColors.surfaceDark,
        onPrimary: AppColors.white,
        onPrimaryContainer: _container(primary),
        onSurface: AppColors.textPrimaryDark,
        onSurfaceVariant: AppColors.textSecondaryDark,
        outline: AppColors.borderDark,
        outlineVariant: AppColors.dividerDark,
        surfaceContainerLow: AppColors.backgroundDark,
        surfaceContainerHigh: const Color(0xFF323232),
        surfaceContainerHighest: const Color(0xFF3D3D3D),
        shadow: AppColors.shadow,
        // Repurposed roles below carry brand/status meaning, not their
        // Material name — see AppTheme doc comment for the full map.
        tertiary: AppColors.cod,
        secondaryContainer: AppColors.prepaid,
        tertiaryContainer: AppColors.assigned,
        onSecondaryContainer: AppColors.completed,
        errorContainer: AppColors.pending,
        onErrorContainer: AppColors.cancelled,
        onSecondaryFixed: AppColors.returnRed,
        inversePrimary: AppColors.info,
        primaryFixedDim: AppColors.delivered,
        surfaceContainerLowest: AppColors.neutralBg,
        onTertiary: AppColors.onPrimaryAccent,
        onTertiaryContainer: AppColors.primarySurface,
        onPrimaryFixedVariant: AppColors.star,
        onSecondary: AppColors.bottomNavInactiveBlackDark,
        surfaceDim: AppColors.bottomNavLightGrayDark,
        tertiaryFixed: primary,
        surfaceBright: primary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryDark,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardDark,
        elevation: 2,
        shadowColor: AppColors.shadowDark,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.r12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return primary.withValues(alpha: 0.6);
            }
            return primary;
          }),
          foregroundColor: WidgetStateProperty.all(AppColors.white),
          overlayColor: WidgetStateProperty.all(
            AppColors.white.withValues(alpha: 0.12),
          ),
          minimumSize: WidgetStateProperty.all(const Size(double.infinity, 52)),
          shape: WidgetStateProperty.all(
            const RoundedRectangleBorder(borderRadius: _buttonRadius),
          ),
          elevation: WidgetStateProperty.all(0),
          shadowColor: WidgetStateProperty.all(AppColors.transparent),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDark,
        contentPadding: const EdgeInsetsDirectional.symmetric(
          horizontal: ThemeConstants.paddingL,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.r10,
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.r10,
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.r10,
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.r10,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.r10,
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        hintStyle: const TextStyle(
          color: AppColors.textSecondaryDark,
          fontSize: 14,
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
        displayMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        displaySmall: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        headlineLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
        headlineMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(double.infinity, 52),
          side: BorderSide(color: primary, width: 1.5),
          shape: const RoundedRectangleBorder(borderRadius: _buttonRadius),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: AppColors.textSecondaryDark,
        indicatorColor: primary,
        indicatorSize: TabBarIndicatorSize.tab,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return null;
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        selectedItemColor: primary,
        unselectedItemColor: AppColors.iconDark,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerDark,
        thickness: 1,
      ),
    );
  }
}
