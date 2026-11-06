import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:flutter/material.dart';

/// Decorative hub in the centre of the wheel: a thin rim, a bright-centred
/// disc and a star.
///
/// Every colour is derived from [ringColor] (`campaign.theme.border_color`
/// from the config API), so the hub always matches the wheel's ring and
/// re-themes with the backend. It ignores touches — spinning starts only from
/// the SPIN button in the board's tray.
class SpinWheelHub extends StatelessWidget {
  /// Diameter of the wheel this hub sits in; the hub is a fraction of it.
  final double wheelSize;

  /// The wheel ring's color; the hub's colors are shades of it.
  final Color ringColor;

  /// `campaign.theme.hub_icon_url`. Shown in the centre; when null/empty (or
  /// it fails to load) the default star is shown instead.
  final String? iconUrl;

  const SpinWheelHub({
    super.key,
    required this.wheelSize,
    required this.ringColor,
    this.iconUrl,
  });

  static const _sizeFraction = 0.17;
  static const _rimFraction = 0.035; // rim thickness, of the hub size
  static const _starFraction = 0.8; // star size, of the hub size

  @override
  Widget build(BuildContext context) {
    final size = wheelSize * _sizeFraction;
    final hsl = HSLColor.fromColor(ringColor);
    Color shade(double lightnessDelta) => hsl
        .withLightness((hsl.lightness + lightnessDelta).clamp(0.0, 1.0))
        .toColor();
    // Star: the ring's hue nudged toward orange and made vivid. Simply
    // darkening a yellow ring would turn it olive-brown.
    final starColor = hsl
        .withHue((hsl.hue - 14) % 360)
        .withSaturation((hsl.saturation + 0.2).clamp(0.0, 1.0))
        .withLightness((hsl.lightness - 0.08).clamp(0.0, 1.0))
        .toColor();

    final iconSize = size * _starFraction;
    // The inner disc (hub minus the rim): the image fills it and is clipped to
    // a circle, so it can never spill past the hub.
    final discSize = size * (1 - 2 * _rimFraction);
    final hasIcon = iconUrl != null && iconUrl!.trim().isNotEmpty;
    final star = Icon(Icons.star_rounded, size: iconSize, color: starColor);

    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * _rimFraction),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // Rim: a lighter tint of the ring color fading to the ring color.
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [shade(0.18), ringColor],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Bright middle fading to a deeper edge, like the reference.
            gradient: RadialGradient(
              radius: 0.85,
              colors: [shade(0.12), ringColor, shade(-0.08)],
              stops: const [0, 0.55, 1],
            ),
          ),
          child: Center(
            child: hasIcon
                ? ClipOval(
                    child: AppNetworkImage(
                      url: iconUrl!,
                      width: discSize,
                      height: discSize,
                      fit: BoxFit.cover,
                      errorWidget: star,
                    ),
                  )
                : star,
          ),
        ),
      ),
    );
  }
}
