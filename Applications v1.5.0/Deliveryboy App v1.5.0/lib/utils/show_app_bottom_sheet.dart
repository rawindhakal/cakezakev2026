import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Default content padding for a sheet body — bottom safe-area is added on top
/// of the bottom value by [showAppBottomSheet].
const EdgeInsetsDirectional _defaultSheetPadding =
    EdgeInsetsDirectional.fromSTEB(ThemeConstants.paddingL, ThemeConstants.paddingM, ThemeConstants.paddingL, ThemeConstants.paddingL);

/// Standard bottom sheet launcher.
/// Owns the whole sheet chrome — background colour, top radius, content padding
/// (including bottom safe-area), drag handle and title — so callers only build
/// their own content.
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
  // Rendered at the end of the title row, e.g. a loading indicator.
  Widget? titleTrailing,
  bool showDragHandle = true,
  bool isScrollControlled = true,
  bool isDismissible = true,
  bool enableDrag = true,
  Color? backgroundColor,
  // Colour of the system navigation bar strip while the sheet is open. It
  // follows the sheet's background when that's opaque; pass it explicitly for
  // sheets that are transparent here and paint their own surface.
  Color? navigationBarColor,
  // Set false when the sheet body scrolls and should run under the system
  // navigation bar itself (padding its own end by `context.bottomSafePadding`)
  // instead of stopping above it.
  bool insetBottomSafeArea = true,
  // Pass null when the sheet body handles its own padding (e.g. keyboard insets).
  EdgeInsetsDirectional? padding = _defaultSheetPadding,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: backgroundColor ?? context.cs.surface,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.top20),
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    builder: (sheetContext) {
      Widget content = _SheetBody(
        title: title,
        titleTrailing: titleTrailing,
        showDragHandle: showDragHandle,
        child: builder(sheetContext),
      );

      if (padding != null) {
        content = Padding(
          padding: padding.add(
            EdgeInsetsDirectional.only(
              bottom:
                  (insetBottomSafeArea ? sheetContext.bottomSafePadding : 0) +
                  sheetContext.keyboardInset,
            ),
          ),
          child: content,
        );
      }
      final sheetColor = backgroundColor;
      final navColor =
          navigationBarColor ??
          (sheetColor == null || sheetColor.a == 0
              ? sheetContext.cs.surface
              : sheetColor);
      // The system nav bar strip otherwise keeps the underlying page's colour
      // and shows as a mismatched band under the sheet.
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          systemNavigationBarColor: navColor,
          systemNavigationBarIconBrightness:
              Theme.of(sheetContext).brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
          systemNavigationBarContrastEnforced: false,
        ),
        child: content,
      );
    },
  );
}

/// Drag handle + title header stacked above the caller's content.
class _SheetBody extends StatelessWidget {
  final String? title;
  final Widget? titleTrailing;
  final bool showDragHandle;
  final Widget child;

  const _SheetBody({
    required this.title,
    required this.titleTrailing,
    required this.showDragHandle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!showDragHandle && title == null) return child;

    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      children: [
        if (showDragHandle)
          Center(
            child: Container(
              width: context.screenWidth * 0.107,
              height: context.screenHeight * 0.005,
              decoration: AppDecorations.dragHandle(color: context.cs.outline),
            ),
          ),
        if (title != null) ...[
          if (showDragHandle) AppSpacing.h16,
          Row(
            children: [
              Expanded(
                child: AppText(
                  title!,
                  style: context.tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.cs.onSurface,
                  ),
                ),
              ),
              ?titleTrailing,
            ],
          ),
        ],
        AppSpacing.h12,
        Flexible(child: child),
      ],
    );
  }
}
