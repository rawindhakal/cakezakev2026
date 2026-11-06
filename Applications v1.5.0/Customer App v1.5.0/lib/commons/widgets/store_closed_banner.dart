import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class StoreClosedBanner extends StatelessWidget {
  const StoreClosedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        ThemeConstants.paddingL,
        ThemeConstants.paddingM,
        ThemeConstants.paddingL,
        ThemeConstants.paddingM,
      ),
      child: Container(
        decoration: AppDecorations.box(
          color: context.cs.error.withValues(alpha: 0.08),
          borderRadius: AppRadius.r16,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: EdgeInsetsDirectional.only(
                start: ThemeConstants.paddingL,
                top: ThemeConstants.paddingL,
                bottom: ThemeConstants.paddingL,
                end: ThemeConstants.paddingM + context.widthFraction(0.2),
              ),
              child: Column(
                crossAxisAlignment: .start,
                mainAxisSize: .min,
                children: [
                  IntrinsicWidth(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CustomPaint(
                          painter: _TagStringPainter(color: context.cs.error),
                        ),
                        AppText(
                          context.translate(LanguageLabelKeys.closedRightNow),
                          style: context.tt.titleLarge?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: context.cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.h8,
                  AppText(
                    context.translate(
                      LanguageLabelKeys.storeClosedBannerMessage,
                    ),
                    style: context.tt.bodyMedium?.copyWith(
                      color: context.cs.onSurface,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            PositionedDirectional(
              top: 0,
              end: 10,
              child: Lottie.asset(
                AssetsConstants.storeClosed,
                height: context.widthFraction(0.2),
                width: context.widthFraction(0.2),
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagStringPainter extends CustomPainter {
  final Color color;
  _TagStringPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const tilt = 0.0;
    canvas.drawLine(
      Offset(size.width * 0.22, size.height),
      Offset(size.width * 0.22 + tilt, 0),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.78, size.height),
      Offset(size.width * 0.78 + tilt, 0),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _TagStringPainter oldDelegate) =>
      oldDelegate.color != color;
}
