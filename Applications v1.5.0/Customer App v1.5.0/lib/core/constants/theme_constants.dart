/// Central design token file — raw double values for spacing, sizing, and components.
///
/// Use these when you need a plain number:
///   • Column/Row `spacing:` param
///   • EdgeInsets padding values
///   • Component heights / icon sizes / border widths
///
/// For pre-built SizedBox widgets → use AppSpacing (h8, w16…)
/// For pre-built BorderRadius     → use AppRadius  (r8, r12…)
class ThemeConstants {
  ThemeConstants._();

  // ── Spacing / gap doubles ─────────────────────────────────────────────────
  /// 2px — tightest gaps, label-value micro spacing
  static const double spaceXXS = 2;

  /// 4px — tiny gaps, label-to-asterisk
  static const double spaceXS = 4;

  /// 8px — button inner icon gap, small row spacing
  static const double spaceS = 8;

  /// 12px — card inner gap, compact sections
  static const double spaceM = 12;

  /// 16px — standard vertical/horizontal gap
  static const double spaceL = 16;

  /// 20px — medium section gap
  static const double spaceXL = 20;

  /// 24px — between major sections
  static const double spaceXXL = 24;

  /// 32px — large dividers, hero spacing
  static const double spaceXXXL = 32;

  // ── Padding doubles (use in EdgeInsets) ───────────────────────────────────
  /// 4px
  static const double paddingXS = 4;

  /// 8px
  static const double paddingS = 8;

  /// 12px — card inner padding
  static const double paddingM = 12;

  /// 16px — standard page / card padding
  static const double paddingL = 16;

  /// 20px — section horizontal padding
  static const double paddingXL = 20;

  /// 24px — large section padding
  static const double paddingXXL = 24;

  // ── Component heights ─────────────────────────────────────────────────────
  /// 48px — all text input field heights
  static const double inputHeight = 48;

  /// 52px — filled primary buttons (FilledButton minSize in AppTheme)
  static const double buttonHeightPrimary = 52;

  /// 44px — outlined / secondary buttons
  static const double buttonHeightSecondary = 44;

  /// 36px — small compact buttons
  static const double buttonHeightSmall = 36;

  /// 56px — top app bars
  static const double appBarHeight = 56;

  /// 60px — bottom navigation bar
  static const double bottomBarHeight = 60;

  // ── Icon sizes ────────────────────────────────────────────────────────────
  /// 12px — tiny inline icons, dense chips
  static const double iconXXS = 12;

  /// 16px — badge icons, small indicators
  static const double iconXS = 16;

  /// 18px — dropdown carets, trailing icons
  static const double iconS = 18;

  /// 20px — standard action icons
  static const double iconM = 20;

  /// 24px — nav bar icons, large actions
  static const double iconL = 24;

  /// 32px — feature / hero icons
  static const double iconXL = 32;

  // ── Border widths ─────────────────────────────────────────────────────────
  /// 0.8px — subtle dividers
  static const double borderSubtle = 0.8;

  /// 1px — standard border
  static const double borderThin = 1;

  /// 1.5px — section / card borders
  static const double borderMedium = 1.5;

  /// 2px — thick / focused borders
  static const double borderThick = 2;

  // ── Loader ────────────────────────────────────────────────────────────────
  /// 16px — circular progress in tight spaces
  static const double loaderSizeS = 16;

  /// 20px — circular progress inside buttons
  static const double loaderSize = 20;

  /// 2px — loader stroke width
  static const double loaderStroke = 2;
}
