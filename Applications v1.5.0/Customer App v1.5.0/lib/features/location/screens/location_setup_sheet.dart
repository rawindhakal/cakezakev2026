import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/address/widgets/location_permission_dialog.dart';
import 'package:customer/features/location/cubit/user_location_cubit.dart';
import 'package:customer/features/location/screens/location_search_screen.dart';
import 'package:customer/features/location/widgets/country_zone_selector.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/utils/show_app_bottom_sheet.dart';
import 'package:customer/commons/animations/slide_animation.dart';
import 'package:customer/core/constants/theme_constants.dart';

/// Shows the Zomato/Blinkit-style location setup bottom sheet.
/// Resolves when location is confirmed or user dismisses.
Future<void> showLocationSetupSheet(BuildContext context) {
  return showAppBottomSheet<void>(
    context,
    showDragHandle: false,
    padding: null,
    builder: (_) => BlocProvider(
      create: (_) => UserLocationCubit(),
      child: const _LocationSetupSheet(),
    ),
  );
}

class _LocationSetupSheet extends StatelessWidget {
  const _LocationSetupSheet();

  @override
  Widget build(BuildContext context) {
    return BlocListener<UserLocationCubit, UserLocationState>(
      listener: (context, state) async {
        if (state is UserLocationDetected) {
          // Location saved — close sheet
          if (context.mounted) AppNavigator.pop(context);
        } else if (state is UserLocationPermissionDenied) {
          // Both denied and deniedForever — show settings dialog
          await showLocationPermissionDialog(context);
          if (context.mounted) {
            context.read<UserLocationCubit>().reset();
          }
        } else if (state is UserLocationError) {
          // Show snack-bar, reset cubit so user can retry
          if (context.mounted) {
            AppSnackBar.show(
              context: context,
              message: state.message,
              type: SnackBarType.error,
            );
            context.read<UserLocationCubit>().reset();
          }
        }
      },
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: ThemeConstants.paddingXXL,
          end: ThemeConstants.paddingXXL,
          top: ThemeConstants.paddingM,
          bottom:
              context.keyboardInset +
              ThemeConstants.spaceXXXL +
              context.bottomSafePadding,
        ),
        child: SlideAnimationList(
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: AppDecorations.dragHandle(
                color: context.cs.outlineVariant,
              ),
            ),
            AppSpacing.h24,

            // Location pin icon
            Container(
              width: 72,
              height: 72,
              decoration: AppDecorations.box(
                color: context.cs.primaryContainer,
                shape: .circle,
              ),
              padding: EdgeInsetsDirectional.all(ThemeConstants.paddingM),
              child: AppSvgIcon(
                AssetsConstants.addressIcon,
                size: ThemeConstants.iconL,
                color: context.cs.primary,
              ),
            ),
            AppSpacing.h20,

            // Heading
            AppText(
              context.translate(LanguageLabelKeys.whereShouldWeDeliver),
              textAlign: .center,
              style: context.tt.headlineSmall?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: context.cs.onSurface,
              ),
            ),
            AppSpacing.h8,

            // Subtitle
            AppText(
              context.translate(LanguageLabelKeys.shareLocationDeliveryMessage),
              textAlign: .center,
              style: context.tt.bodyMedium?.copyWith(
                color: context.cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            AppSpacing.h28,

            // Buttons — reactive to cubit state
            BlocBuilder<UserLocationCubit, UserLocationState>(
              builder: (context, state) {
                final isDetecting = state is UserLocationDetecting;
                return Column(
                  spacing: ThemeConstants.spaceM,
                  children: [
                    // Use current location
                    AppButton(
                      label: isDetecting
                          ? context.translate(
                              LanguageLabelKeys.detectingLocation,
                            )
                          : context.translate(
                              LanguageLabelKeys.useCurrentLocation,
                            ),
                      height: 52,
                      isLoading: isDetecting,
                      onPressed: () => context
                          .read<UserLocationCubit>()
                          .detectCurrentLocation(),
                      prefixIcon: AppSvgIcon(
                        AssetsConstants.enableLocationIcon,
                        size: ThemeConstants.iconM,
                        color: context.cs.onPrimary,
                      ),
                    ),

                    // Search manually
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: isDetecting
                            ? null
                            : () async {
                                final picked = await AppNavigator.push<bool>(
                                  context,
                                  const LocationSearchScreen(),
                                );
                                if (picked == true && context.mounted) {
                                  AppNavigator.pop(context);
                                }
                              },
                        icon: AppSvgIcon(
                          AssetsConstants.searchIcon,
                          size: ThemeConstants.iconS,
                          color: context.cs.onSurfaceVariant,
                          fit: BoxFit.scaleDown,
                        ),
                        label: AppText(
                          context.translate(
                            LanguageLabelKeys.searchLocationManually,
                          ),
                          style: context.tt.bodyMedium?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.cs.onSurface,
                          side: BorderSide(color: context.cs.outlineVariant),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.r12,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            AppSpacing.h24,

            // Country + delivery-zone picker
            CountryZoneSelector(
              onLocationConfirmed: () => AppNavigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
