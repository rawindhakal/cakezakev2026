import 'dart:math' as math;

import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/theme/app_colors.dart';
import 'package:customer/core/utils/color_utils.dart';
import 'package:customer/features/spin_wheel/models/spin_wheel_model.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';

/// Icon + short label for every prize, laid over the wheel's slices.
///
/// The labels rotate with the wheel: [rotation] is the wheel's current angle
/// in radians and drives a per-frame transform. The icon/text content itself
/// is built once per build and reused every frame, so a spin only re-runs the
/// cheap translate/rotate wrappers, not the image and text widgets.
class SpinWheelPrizeLabels extends StatelessWidget {
  final List<SpinSegment> segments;
  final Animation<double> rotation;

  /// Diameter of the wheel these labels sit on.
  final double wheelSize;

  const SpinWheelPrizeLabels({
    super.key,
    required this.segments,
    required this.rotation,
    required this.wheelSize,
  });

  /// Distance of a label's centre from the wheel's centre, as a fraction of
  /// the wheel radius (mid-slice).
  static const _radiusFraction = 0.62;

  /// Label width as a share of the slice's chord at that radius, so long
  /// labels wrap inside their own wedge instead of spilling into neighbors.
  static const _chordFraction = 0.72;
  static const _iconSizeFraction = 0.07; // of wheel diameter
  static const _labelFontSize = 9.5;

  /// Labels lean toward their slice's angle by at most this much (radians).
  /// They are never flipped upside-down: flipping would reverse the
  /// icon-then-text order on the lower slices and look inconsistent.
  static const _maxTilt = math.pi / 5;

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) return const SizedBox.shrink();

    final sliceAngle = 2 * math.pi / segments.length;
    final radius = wheelSize / 2 * _radiusFraction;
    final maxLabelWidth =
        2 * radius * math.sin(sliceAngle / 2) * _chordFraction;
    final iconSize = wheelSize * _iconSizeFraction;

    // Built once; only the transforms below change per frame.
    final contents = [
      for (final segment in segments)
        _labelContent(context, segment, maxLabelWidth, iconSize),
    ];

    return AnimatedBuilder(
      animation: rotation,
      builder: (context, _) {
        // Explicit size: with no Positioned children, Stack would otherwise
        // shrink-wrap the (small, centered) label boxes — Transform.translate
        // still paints labels out at the wheel's rim, but taps landing there
        // fall outside that shrunk hit-test box and never reach them.
        return SizedBox(
          width: wheelSize,
          height: wheelSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < segments.length; i++)
                _placed(
                  content: contents[i],
                  sliceCenter: (i + 0.5) * sliceAngle,
                  radius: radius,
                ),
            ],
          ),
        );
      },
    );
  }

  /// Moves [content] to the middle of its slice and tilts it slightly.
  Widget _placed({
    required Widget content,
    required double sliceCenter,
    required double radius,
  }) {
    // Slice 0 starts at the top (-pi/2); the wheel's rotation shifts it.
    final position = sliceCenter + rotation.value - math.pi / 2;
    var tilt = sliceCenter + rotation.value;
    tilt = ((tilt + math.pi) % (2 * math.pi)) - math.pi; // normalise to ±pi
    tilt = tilt.clamp(-_maxTilt, _maxTilt);
    return Transform.translate(
      offset: Offset(radius * math.cos(position), radius * math.sin(position)),
      child: Transform.rotate(angle: tilt, child: content),
    );
  }

  Widget _labelContent(
    BuildContext context,
    SpinSegment segment,
    double width,
    double iconSize,
  ) {
    final textColor = parseHexColor(
      segment.textColor,
      fallback: AppColors.spinWheelCrimsonDark,
    );
    final segmentColor = parseHexColor(
      segment.color,
      fallback: AppColors.spinWheelCrimsonDark,
    );
    return Tooltip(
      message: segment.label,
      triggerMode: TooltipTriggerMode.tap,
      decoration: BoxDecoration(
        color: segmentColor,
        borderRadius: BorderRadius.circular(4),
      ),
      textStyle: context.tt.labelSmall?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w700,
      ),
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppNetworkImage(
              url: segment.iconUrl,
              width: iconSize,
              height: iconSize,
              // Soft round dot in the slice's text color while loading,
              // instead of the default grey square.
              placeholder: Container(
                width: iconSize,
                height: iconSize,
                alignment: Alignment.center,
                child: Container(
                  width: iconSize * 0.7,
                  height: iconSize * 0.7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: textColor.withValues(alpha: 0.18),
                  ),
                ),
              ),
              errorWidget: Icon(
                Icons.card_giftcard,
                size: iconSize,
                color: textColor,
              ),
            ),
            const SizedBox(height: ThemeConstants.spaceXXS),
            AppText(
              segment.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.tt.labelSmall?.copyWith(
                color: textColor,
                fontSize: _labelFontSize,
                fontWeight: FontWeight.w700,
                height: 1.05,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
