import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/loading_widget.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/commons/widgets/app_button.dart';

import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/core/constants/theme_constants.dart';

/// Bottom card shared by the delivery-address picker and the zone picker
/// ([ZoneLocationPickerScreen]) — drag handle, title/subtitle row,
/// current-location button, zone-unavailable banner, confirm CTA. The two
/// callers differ in how their confirm button's busy/disabled state is
/// driven (address picker has a separate async zone-check API call; the
/// zone picker's check is synchronous/local), so that's left to the caller
/// via [confirmIsLoading]/[confirmDisabled] rather than derived here.
class LocationConfirmCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isLocating;
  final String confirmLabel;
  final bool confirmIsLoading;
  final bool confirmDisabled;

  /// null = no boundary/zone data to test against, so availability can't be
  /// verified — banner stays hidden and confirm behaves as available.
  final bool? isAvailable;

  /// True while an availability check is still in flight — suppresses the
  /// unavailable banner until it resolves. Address picker only; the zone
  /// picker's check is synchronous so this stays false there.
  final bool isAvailabilityChecking;
  final VoidCallback onConfirm;
  final VoidCallback onCurrentLocation;

  const LocationConfirmCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isLocating,
    required this.confirmLabel,
    required this.confirmIsLoading,
    required this.confirmDisabled,
    required this.onConfirm,
    required this.onCurrentLocation,
    this.isAvailable,
    this.isAvailabilityChecking = false,
  });

  bool get _zoneUnavailable => isAvailable == false && !isAvailabilityChecking;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.bottomSheet(
        color: context.cs.surface,
        borderRadius: AppRadius.top20,
        boxShadow: [
          BoxShadow(
            color: context.cs.scrim.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            ThemeConstants.paddingL,
            ThemeConstants.paddingL,
            ThemeConstants.paddingL,
            ThemeConstants.paddingL,
          ),
          child: Column(
            mainAxisSize: .min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsetsDirectional.only(
                    bottom: ThemeConstants.paddingM,
                  ),
                  decoration: AppDecorations.dragHandle(
                    color: context.cs.outlineVariant,
                  ),
                ),
              ),
              if (!_zoneUnavailable)
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: AppDecorations.primaryIconBox(
                        color: context.cs.primary.withValues(alpha: 0.1),
                      ),
                      child: AppSvgIcon(
                        AssetsConstants.addressIcon,
                        color: context.cs.primary,
                        size: ThemeConstants.iconM,
                        fit: BoxFit.scaleDown,
                      ),
                    ),
                    AppSpacing.w12,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: .start,
                        children: [
                          AppText(
                            title,
                            style: context.tt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: context.cs.onSurface,
                            ),
                            maxLines: 1,
                            overflow: .ellipsis,
                          ),
                          if (subtitle.isNotEmpty)
                            AppText(
                              subtitle,
                              style: context.tt.bodySmall?.copyWith(
                                color: context.cs.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: .ellipsis,
                            ),
                        ],
                      ),
                    ),
                    AppSpacing.w8,
                    Material(
                      color: context.cs.surface,
                      borderRadius: AppRadius.r10,
                      child: InkWell(
                        borderRadius: AppRadius.r10,
                        onTap: isLocating ? null : onCurrentLocation,
                        child: Container(
                          padding: const EdgeInsetsDirectional.all(
                            ThemeConstants.paddingS,
                          ),
                          decoration: AppDecorations.outlinedCard(
                            borderColor: context.cs.outlineVariant,
                          ),
                          child: isLocating
                              ? LoadingWidget(size: ThemeConstants.loaderSize)
                              : AppSvgIcon(
                                  AssetsConstants.enableLocationIcon,
                                  color: context.cs.primary,
                                  size: ThemeConstants.iconM,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              if (_zoneUnavailable) ...[
                _ZoneUnavailableBanner(context: context),
                AppSpacing.h12,
                AppButton(
                  label: context.translate(
                    LanguageLabelKeys.useCurrentLocation,
                  ),
                  height: 50,
                  onPressed: onCurrentLocation,
                  prefixIcon: AppSvgIcon(
                    AssetsConstants.enableLocationIcon,
                    size: ThemeConstants.iconS,
                    color: context.cs.onPrimary,
                  ),
                ),
              ] else ...[
                AppSpacing.h14,
                AppButton(
                  label: confirmLabel,
                  height: 50,
                  isLoading: confirmIsLoading,
                  onPressed: confirmDisabled ? null : onConfirm,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ZoneUnavailableBanner extends StatelessWidget {
  final BuildContext context;
  const _ZoneUnavailableBanner({required this.context});

  @override
  Widget build(BuildContext ctx) {
    return Column(
      spacing: ThemeConstants.spaceS,
      children: [
        AppText(
          ctx.translate(LanguageLabelKeys.zoneUnavailableTitle),
          textAlign: .center,
          style: ctx.tt.titleMedium?.copyWith(color: ctx.cs.onSurface),
        ),
        AppText(
          ctx.translate(LanguageLabelKeys.zoneUnavailableSubtitle),
          textAlign: .center,
          style: ctx.tt.bodySmall?.copyWith(
            fontSize: 13,
            color: ctx.cs.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
