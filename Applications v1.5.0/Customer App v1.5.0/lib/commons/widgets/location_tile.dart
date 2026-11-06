import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:flutter/material.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_decorations.dart';
import '../../commons/widgets/app_text.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:url_launcher/url_launcher.dart';

enum LocationType { pickup, drop }

class LocationTile extends StatelessWidget {
  final String address;
  final String city;
  final String? contactPhone;
  final LocationType type;

  const LocationTile({
    super.key,
    required this.address,
    required this.city,
    this.contactPhone,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final isPickup = type == LocationType.pickup;
    final iconColor = isPickup ? context.cs.errorContainer : context.cs.error;
    final label = context.translate(
      isPickup
          ? LanguageLabelKeys.pickupLocation
          : LanguageLabelKeys.dropLocation,
    );

    return Column(
      crossAxisAlignment: .start,
      spacing: ThemeConstants.spaceS,
      children: [
        AppText(
          label,
          style: context.tt.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.cs.onSurfaceVariant,
          ),
        ),
        Row(
          crossAxisAlignment: .start,
          spacing: ThemeConstants.spaceS,
          children: [
            AppSvgIcon(
              isPickup ? AssetsConstants.addressIcon : AssetsConstants.flagIcon,
              color: iconColor,
              size: ThemeConstants.iconM,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  AppText(
                    city,
                    style: context.tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.cs.onSurface,
                    ),
                  ),
                  AppSpacing.h2,
                  AppText(
                    address,
                    style: context.tt.bodySmall?.copyWith(
                      fontSize: 13,
                      color: context.cs.onSurfaceVariant,
                    ),
                  ),
                  if (contactPhone != null) ...[
                    AppSpacing.h4,
                    AppText(
                      '${context.translate(LanguageLabelKeys.contactLabel)} $contactPhone',
                      style: context.tt.bodySmall?.copyWith(
                        color: context.cs.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (contactPhone != null)
              GestureDetector(
                onTap: () async {
                  final phone = contactPhone!;
                  final uri = Uri.parse('tel:$phone');
                  try {
                    if (await canLaunchUrl(uri)) launchUrl(uri);
                  } catch (_) {}
                },
                child: Container(
                  padding: const EdgeInsetsDirectional.all(
                    ThemeConstants.paddingS,
                  ),
                  decoration: AppDecorations.box(
                    color: context.cs.primaryContainer,
                    borderRadius: AppRadius.r8,
                  ),
                  child: AppSvgIcon(
                    AssetsConstants.phoneIcon,
                    color: context.cs.primary,
                    size: ThemeConstants.iconS,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
