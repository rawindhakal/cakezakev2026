import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/show_app_bottom_sheet.dart';
import 'package:customer/commons/animations/slide_animation.dart';
import 'package:customer/core/constants/theme_constants.dart';

/// Text with a dashed underline that shows [message] in a bottom sheet on
/// tap — used to flag refundable/non-refundable charge rows.
class DashedUnderlineTooltip extends StatelessWidget {
  const DashedUnderlineTooltip({
    super.key,
    required this.text,
    required this.message,
    this.style,
    this.dashColor,
    this.sheetTitle,
    this.contentBuilder,
  });

  final String text;
  final String message;
  final TextStyle? style;
  final Color? dashColor;

  /// Overrides [text] as the bottom sheet's title, when set.
  final String? sheetTitle;

  /// Overrides the default plain-message body with custom sheet content.
  final WidgetBuilder? contentBuilder;

  void _showInfoSheet(BuildContext context) {
    showAppBottomSheet(
      context,
      isScrollControlled: false,
      title: sheetTitle ?? text,
      padding: const EdgeInsetsDirectional.fromSTEB(
        ThemeConstants.paddingL,
        ThemeConstants.paddingM,
        ThemeConstants.paddingL,
        ThemeConstants.spaceXXXL,
      ),
      builder: (sheetContext) => SlideAnimationList(
        children: [
          if (contentBuilder != null)
            contentBuilder!(sheetContext)
          else
            AppText(
              message,
              style: sheetContext.tt.bodySmall?.copyWith(
                color: sheetContext.cs.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolvedStyle = style ?? DefaultTextStyle.of(context).style;
    final color = dashColor ?? resolvedStyle.color ?? context.cs.onSurface;
    return GestureDetector(
      onTap: () => _showInfoSheet(context),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: .start,
          mainAxisSize: .min,
          children: [
            AppText(text, style: resolvedStyle),
            AppSpacing.h1,
            CustomPaint(
              size: const Size(double.infinity, 1),
              painter: _DashedLinePainter(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;
  static const double _dashWidth = 3;
  static const double _dashGap = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + _dashWidth, 0), paint);
      x += _dashWidth + _dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
