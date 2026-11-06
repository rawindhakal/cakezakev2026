import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/location/widgets/country_zone_selector.dart';
import 'package:customer/core/constants/theme_constants.dart';

class LocationRequiredView extends StatelessWidget {
  final VoidCallback onSetLocation;
  final VoidCallback onSearchManually;
  final VoidCallback onLocationConfirmed;
  final bool isSettingLocation;
  const LocationRequiredView({
    super.key,
    required this.onSetLocation,
    required this.onSearchManually,
    required this.onLocationConfirmed,
    this.isSettingLocation = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      applyBottomInset: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: ThemeConstants.spaceXXXL,
              vertical: ThemeConstants.paddingL,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: .center,
                children: [
                  AppSvgIcon(
                    AssetsConstants.weAreNotHere,
                    size: context.widthFraction(0.385),
                    color: context.cs.primary,
                    useColorMapper: true,
                  ),
                  AppSpacing.h28,
                  AppText(
                    context.translate(LanguageLabelKeys.whereShouldWeDeliver),
                    textAlign: .center,
                    style: context.tt.headlineSmall?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: context.cs.onSurface,
                      height: 1.25,
                    ),
                  ),
                  AppSpacing.h10,
                  AppText(
                    context.translate(
                      LanguageLabelKeys.shareLocationOffersMessage,
                    ),
                    textAlign: .center,
                    style: context.tt.bodyMedium?.copyWith(
                      color: context.cs.onSurfaceVariant,
                      height: 1.55,
                    ),
                  ),
                  AppSpacing.h36,
                  AppButton(
                    label: context.translate(
                      LanguageLabelKeys.setDeliveryLocation,
                    ),
                    onPressed: isSettingLocation ? null : onSetLocation,
                    isLoading: isSettingLocation,
                    prefixIcon: AppSvgIcon(
                      AssetsConstants.enableLocationIcon,
                      size: ThemeConstants.iconM,
                      color: context.cs.onPrimary,
                    ),
                  ),
                  AppSpacing.h12,
                  AppButton(
                    label: context.translate(
                      LanguageLabelKeys.searchLocationManually,
                    ),
                    onPressed: isSettingLocation ? null : onSearchManually,
                    variant: AppButtonVariant.outline,
                    prefixIcon: AppSvgIcon(
                      AssetsConstants.searchIcon,
                      size: ThemeConstants.iconS,
                      color: context.cs.primary,
                    ),
                  ),
                  AppSpacing.h24,
                  CountryZoneSelector(
                    onLocationConfirmed: onLocationConfirmed,
                    autoSelectZone: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
