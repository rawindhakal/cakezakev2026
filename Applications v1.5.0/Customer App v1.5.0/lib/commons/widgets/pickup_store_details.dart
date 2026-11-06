import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/api/api_endpoints.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/string_extensions.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Pickup-store info block — avatar + name + open/closed status, address,
/// prep time, and Get-Directions / Call-Store actions. Content only (no
/// outer card decoration) so callers can drop it into whatever container
/// fits their layout — the order-detail card and the checkout bottom bar
/// both show the same store detail, just boxed differently.
class PickupStoreDetails extends StatelessWidget {
  const PickupStoreDetails({
    super.key,
    this.storeName,
    this.address,
    this.latitude,
    this.longitude,
    this.contactNumber,
    this.preparationTime,
    this.preparationMinutes,
    this.isOpenNow,
  });

  final String? storeName;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? contactNumber;
  final String? preparationTime;
  final int? preparationMinutes;
  final bool? isOpenNow;

  static const _avatarSize = 40.0;

  bool get _hasCoords =>
      latitude != null &&
      longitude != null &&
      (latitude != 0 || longitude != 0);

  Future<void> _openMap() async {
    final query = _hasCoords
        ? '$latitude,$longitude'
        : (address.hasValue ? address! : null);
    if (query == null) return;
    final uri = Uri.parse(
      '${ApiEndpoints.googleMapsSearchBaseUrl}${Uri.encodeComponent(query)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _call() async {
    final phone = contactNumber;
    if (!phone.hasValue) return;
    final uri = Uri.parse('tel:$phone');
    try {
      if (await canLaunchUrl(uri)) launchUrl(uri);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final hasAddress = address.hasValue;
    final canOpenMap = hasAddress || _hasCoords;
    final hasContact = contactNumber.hasValue;
    final prep = preparationTime.hasValue
        ? preparationTime!
        : (preparationMinutes != null ? '$preparationMinutes min' : '');
    final isOpen = isOpenNow;

    return Column(
      crossAxisAlignment: .start,
      spacing: ThemeConstants.spaceM,
      children: [
        AppText(
          context.translate(LanguageLabelKeys.pickupFrom),
          style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        Divider(height: 1, color: context.cs.outlineVariant),
        Row(
          crossAxisAlignment: .start,
          spacing: ThemeConstants.spaceS,
          children: [
            Container(
              width: _avatarSize,
              height: _avatarSize,
              alignment: Alignment.center,
              decoration: AppDecorations.primaryIconBox(
                color: context.cs.primaryContainer,
                borderRadius: _avatarSize / 2,
              ),
              child: AppSvgIcon(
                AssetsConstants.storeIcon,
                color: context.cs.primary,
                size: ThemeConstants.iconM,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                spacing: ThemeConstants.spaceXS,
                children: [
                  AppText(
                    storeName.hasValue
                        ? storeName!
                        : context.translate(LanguageLabelKeys.pickUp),
                    style: context.tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: .ellipsis,
                  ),
                  Row(
                    spacing: ThemeConstants.spaceXS,
                    children: [
                      if (isOpen != null) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isOpen
                                ? context.cs.tertiary
                                : context.cs.error,
                          ),
                        ),
                        AppText(
                          context.translate(
                            isOpen
                                ? LanguageLabelKeys.storeOpenNow
                                : LanguageLabelKeys.storeClosedNow,
                          ),
                          style: context.tt.labelSmall?.copyWith(
                            color: isOpen
                                ? context.cs.tertiary
                                : context.cs.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (isOpen != null && prep.isNotEmpty)
                        AppText(
                          '•',
                          style: context.tt.labelSmall?.copyWith(
                            color: context.cs.onSurfaceVariant,
                          ),
                        ),
                      if (prep.isNotEmpty)
                        Flexible(
                          child: AppText(
                            '${context.translate(LanguageLabelKeys.readyForPickupIn)} $prep',
                            style: context.tt.labelSmall?.copyWith(
                              color: context.cs.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: .ellipsis,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (hasAddress)
          Row(
            crossAxisAlignment: .start,
            spacing: ThemeConstants.spaceS,
            children: [
              AppSvgIcon(
                AssetsConstants.addressIcon,
                color: context.cs.onSurfaceVariant,
                size: ThemeConstants.iconS,
              ),
              Expanded(
                child: AppText(
                  address!,
                  style: context.tt.bodySmall?.copyWith(
                    color: context.cs.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: .ellipsis,
                ),
              ),
            ],
          ),
        if (canOpenMap || hasContact) ...[
          Divider(height: 1, color: context.cs.outlineVariant),
          Row(
            spacing: ThemeConstants.spaceS,
            children: [
              if (canOpenMap)
                Expanded(
                  child: AppButton(
                    label: context.translate(LanguageLabelKeys.getDirections),
                    onPressed: _openMap,
                    variant: .outline,
                    height: 38,
                    fontSize: 13,
                    prefixIcon: AppSvgIcon(
                      AssetsConstants.addressIcon,
                      color: context.cs.primary,
                      size: ThemeConstants.iconS,
                    ),
                  ),
                ),
              if (hasContact)
                Expanded(
                  child: AppButton(
                    label: context.translate(LanguageLabelKeys.callStore),
                    onPressed: _call,
                    variant: .secondary,
                    height: 38,
                    fontSize: 13,
                    prefixIcon: AppSvgIcon(
                      AssetsConstants.phoneIcon,
                      color: context.cs.primary,
                      size: ThemeConstants.iconS,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
