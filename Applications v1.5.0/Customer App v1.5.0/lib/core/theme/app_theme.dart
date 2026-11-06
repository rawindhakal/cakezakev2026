import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/constants/theme_constants.dart';

/// ColorScheme has a fixed Material role set with no slot for app-specific
/// brand/status colors, so this app repurposes otherwise-unused roles to
/// carry them (avoids a separate ThemeExtension — use `context.cs.<role>`
/// instead). Role -> actual meaning:
/// onSecondaryContainer=success, errorContainer=warning,
/// onPrimaryFixedVariant=star, onSecondaryFixed=favourite, tertiaryFixed=credit,
/// onTertiaryFixed=debit, inversePrimary=info, onTertiaryContainer=cod,
/// secondaryFixed=categoryTileBg, surfaceDim=surface(semantic),
/// onPrimaryFixed=textStrong, onSecondaryFixedVariant=border(semantic),
/// surfaceBright=divider2, onSecondary=bottomNavInactiveBlack,
/// tertiaryFixedDim=bottomNavLightGray, primaryFixed=bottomNavActiveBlack,
/// primaryFixedDim=bottomNavConstant.
/// (`shadow`, `scrim`, `tertiary`, `tertiaryContainer`, `secondaryContainer`,
/// `onError`, `inverseSurface`/`onInverseSurface`, `surfaceContainerLowest`
/// are already used for their real Material meaning elsewhere; `surfaceTint`
/// is NOT free even though nothing in this codebase calls it explicitly —
/// Material3 `Card`/`Dialog`/`BottomSheet` read it automatically for the
/// elevation tint overlay, so repurposing it tints every elevated surface
/// app-wide. Do not repurpose any of these.)
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

  /// Darkens [c] toward black — used for the "on container" role so it
  /// always contrasts against the container tint derived from the same
  /// runtime (API-driven) primary color.
  static Color _darken(Color c) => Color.fromARGB(
    255,
    _ch((c.r * 255.0) * 0.7),
    _ch((c.g * 255.0) * 0.7),
    _ch((c.b * 255.0) * 0.7),
  );

  /// Lightens [c] toward white by 88% — used for the "container" role
  /// (pale tint of the runtime primary), independent of the fixed
  /// AppColors placeholder.
  static Color _container(Color c) => Color.fromARGB(
    255,
    _ch(c.r * 255.0 + (255 - c.r * 255.0) * 0.88),
    _ch(c.g * 255.0 + (255 - c.g * 255.0) * 0.88),
    _ch(c.b * 255.0 + (255 - c.b * 255.0) * 0.88),
  );

  /// Lightens [c] toward white by 30% — used for the light-theme "secondary"
  /// role, a lighter tint of the runtime primary.
  static Color _lighten(Color c) => Color.fromARGB(
    255,
    _ch(c.r * 255.0 + (255 - c.r * 255.0) * 0.3),
    _ch(c.g * 255.0 + (255 - c.g * 255.0) * 0.3),
    _ch(c.b * 255.0 + (255 - c.b * 255.0) * 0.3),
  );

  static ThemeData lightTheme(Color primary) {
    final primaryDark = _darken(primary);
    final primaryLight = _lighten(primary);
    final primaryContainer = _container(primary);

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppConfig.fontFamily,
      brightness: Brightness.light,
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
        surfaceContainer: const Color(0xFFF6F7F8),
        surfaceContainerHigh: const Color(0xFFF0F0F0),
        surfaceContainerHighest: const Color(0xFFEAEAEA),
        // Repurposed roles below carry brand/status meaning, not their
        // Material name — see AppTheme doc comment for the full map.
        onSecondaryContainer: const Color(0xFF2E7D32), // success
        errorContainer: const Color(0xFFF57F17), // warning
        onPrimaryFixedVariant: const Color(0xFFFFC107), // star
        onSecondaryFixed: const Color(0xFFF44336), // favourite
        tertiaryFixed: const Color(0xFF4CAF50), // credit
        onTertiaryFixed: const Color(0xFFFF9800), // debit
        inversePrimary: const Color(0xFF0288D1), // info
        onTertiaryContainer: const Color(0xFFE65100), // cod
        secondaryFixed: const Color(0xFFE5F3F3), // categoryTileBg
        surfaceDim: const Color(0xFFFFFFFF), // surface(semantic)
        onPrimaryFixed: const Color(0xFF111111), // textStrong
        onSecondaryFixedVariant: const Color(0xFFE1E1E1), // border(semantic)
        surfaceBright: const Color(0xFFEDEDED), // divider2
        onSecondary: const Color(0xFF333333), // bottomNavInactiveBlack
        tertiaryFixedDim: const Color(0xFFE1E1E1), // bottomNavLightGray
        primaryFixed: const Color(0xFF444444), // bottomNavActiveBlack
        primaryFixedDim: const Color(0xFFFFFFFF), // bottomNavConstant
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
          vertical: ThemeConstants.paddingM,
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
          if (states.contains(WidgetState.selected)) return primary;
          return null;
        }),
      ),
    );
  }

  static ThemeData darkTheme(Color primary) {
    final primaryDark = _darken(primary);

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppConfig.fontFamily,
      brightness: Brightness.dark,
      primaryColor: primary,
      pageTransitionsTheme: _pageTransitionsTheme,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      colorScheme: ColorScheme.dark(
        primary: primary,
        // Darkened (not lightened) so it still reads as a "container"
        // tint against the app's dark background, while staying visibly
        // distinct from `primary` itself (was hardcoded equal to primary
        // before — made icons on primaryContainer backgrounds invisible).
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
        surfaceContainer: const Color(0xFF2A2A2A),
        surfaceContainerHigh: const Color(0xFF323232),
        surfaceContainerHighest: const Color(0xFF3D3D3D),
        // Repurposed roles below carry brand/status meaning, not their
        // Material name — see AppTheme doc comment for the full map.
        onSecondaryContainer: const Color(0xFF81C784), // success
        errorContainer: const Color(0xFFFFB74D), // warning
        onPrimaryFixedVariant: const Color(0xFFFFD54F), // star
        onSecondaryFixed: const Color(0xFFF44336), // favourite
        tertiaryFixed: const Color(0xFF81C784), // credit
        onTertiaryFixed: const Color(0xFFFFCC80), // debit
        inversePrimary: const Color(0xFF4FC3F7), // info
        onTertiaryContainer: const Color(0xFFFF8A65), // cod
        secondaryFixed: const Color(0xFF1A2E2E), // categoryTileBg
        surfaceDim: const Color(0xFF000000), // surface(semantic)
        onPrimaryFixed: const Color(0xFFB6B6B6), // textStrong
        onSecondaryFixedVariant: const Color(0xFF737373), // border(semantic)
        surfaceBright: const Color(0xFF434343), // divider2
        onSecondary: const Color(0xFFC8C8C8), // bottomNavInactiveBlack
        tertiaryFixedDim: const Color(0xFF5C5C5C), // bottomNavLightGray
        primaryFixed: primary, // bottomNavActiveBlack (runtime primary)
        primaryFixedDim: primary, // bottomNavConstant (runtime primary)
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardDark,
        elevation: 2,
        shadowColor: AppColors.black26,
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
          vertical: ThemeConstants.paddingM,
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
          if (states.contains(WidgetState.selected)) return primary;
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
