import 'package:deliveryboy/commons/widgets/app_no_internet_widget.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import '../../../core/constants/assets_constants.dart';
import 'ultra_loader.dart';

/// Splash screen logo/loader visual, swapping to a no-internet state when offline.
class SplashVisual extends StatelessWidget {
  final bool showNoInternet;
  const SplashVisual({super.key, required this.showNoInternet});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Align(
          alignment: Alignment.center,
          child: SizedBox.square(
            dimension: context.screenWidth * 0.40,
            child: AppSvgIcon(AssetsConstants.splashLogo),
          ),
        ),
        Align(
          alignment: const AlignmentDirectional(0, 0.75),
          child: UltraLoader(),
        ),
        // Embedded: this overlays the splash's existing scaffold, so it must
        // not nest a second one inside the Stack.
        if (showNoInternet) const AppNoInternetFullScreen(embedded: true),
      ],
    );
  }
}
