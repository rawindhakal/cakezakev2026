import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:deliveryboy/utils/extensions/string_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'order_action_buttons.dart' show launchCall, launchDirection;
import 'package:deliveryboy/commons/widgets/app_text.dart';

/// Shows the Pickup (store) and Delivery (customer address) details for an
/// order. Pickup fields should come from the store-info part of the order
/// model, delivery fields from the address part of the order model.
class PickupDeliveryCard extends StatelessWidget {
  final String? pickupName;
  final String? pickupAddress;
  final String? pickupPhone;
  final String? pickupLatitude;
  final String? pickupLongitude;
  final String? deliveryName;
  final String? deliveryAddress;
  final String? deliveryPhone;
  final String? deliveryLatitude;
  final String? deliveryLongitude;
  final String? deliveryAlternatePhone;
  final VoidCallback? onDeliveryChatTap;

  const PickupDeliveryCard({
    super.key,
    this.pickupName,
    this.pickupAddress,
    this.pickupPhone,
    this.pickupLatitude,
    this.pickupLongitude,
    this.deliveryName,
    this.deliveryAddress,
    this.deliveryPhone,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.deliveryAlternatePhone,
    this.onDeliveryChatTap,
  });

  bool get _hasPickup =>
      pickupAddress.isNotNullOrEmpty ||
      pickupPhone.isNotNullOrEmpty ||
      pickupName.isNotNullOrEmpty;

  bool get _hasDelivery =>
      deliveryAddress.isNotNullOrEmpty ||
      deliveryPhone.isNotNullOrEmpty ||
      deliveryName.isNotNullOrEmpty;

  @override
  Widget build(BuildContext context) {
    if (!_hasPickup && !_hasDelivery) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: ThemeConstants.paddingL),
      padding: const EdgeInsetsDirectional.all(14),
      decoration: AppDecorations.shadowedCard(
        color: Theme.of(context).cardColor,
        shadowColor: context.cs.shadow,
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          if (_hasPickup)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: .start,
                children: [
                  _RouteIcon(
                    icon: AssetsConstants.storeIcon,
                    showLine: _hasDelivery,
                  ),
                  AppSpacing.w12,
                  Expanded(
                    child: _LocationSection(
                      title: context.translate(LanguageLabelKeys.pickupInfo),
                      name: pickupName,
                      address: pickupAddress,
                      phone: pickupPhone,
                      latitude: pickupLatitude,
                      longitude: pickupLongitude,
                    ),
                  ),
                ],
              ),
            ),
          if (_hasDelivery)
            Row(
              crossAxisAlignment: .start,
              children: [
                const _RouteIcon(
                  icon: AssetsConstants.addressIcon,
                  showLine: false,
                ),
                AppSpacing.w12,
                Expanded(
                  child: _LocationSection(
                    title: context.translate(LanguageLabelKeys.deliveryInfo),
                    name: deliveryName,
                    address: deliveryAddress,
                    phone: deliveryPhone,
                    alternatePhone: deliveryAlternatePhone,
                    latitude: deliveryLatitude,
                    longitude: deliveryLongitude,
                    onChatTap: onDeliveryChatTap,
                    // Call button follows the same visibility flag as chat:
                    // only shown when isDeliveryBoyChatVisible == true (which is
                    // exactly when onDeliveryChatTap is non-null).
                    callVisible: onDeliveryChatTap != null,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Icon circle for a pickup/delivery row, with an optional trailing
/// connector line sized to that row's own content height — so the line
/// ends exactly where the next row's icon/title begins, matching the
/// [OrderStatusTimeline] visual language.
class _RouteIcon extends StatelessWidget {
  final String icon;
  final bool showLine;
  const _RouteIcon({required this.icon, required this.showLine});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: context.screenWidth * 0.107,
          height: context.screenWidth * 0.107,
          decoration: AppDecorations.circle(
            color: context.cs.primary.withValues(alpha: 0.14),
          ),
          child: AppSvgIcon(
            icon,
            size: ThemeConstants.iconS,
            color: context.cs.primary,
            fit: BoxFit.scaleDown,
          ),
        ),
        if (showLine)
          Expanded(
            child: Container(
              width: 2,
              margin: const EdgeInsetsDirectional.symmetric(vertical: 1),
              decoration: AppDecorations.card(
                color: context.cs.primary.withValues(alpha: 0.4),
                borderRadius: AppRadius.r2,
              ),
            ),
          ),
      ],
    );
  }
}

class _LocationSection extends StatelessWidget {
  final String title;
  final String? name;
  final String? address;
  final String? phone;
  final String? alternatePhone;
  final String? latitude;
  final String? longitude;
  final VoidCallback? onChatTap;
  final bool callVisible;

  const _LocationSection({
    required this.title,
    this.name,
    this.address,
    this.phone,
    this.alternatePhone,
    this.latitude,
    this.longitude,
    this.onChatTap,
    this.callVisible = true,
  });

  bool get _hasCoordinates =>
      latitude.isNotNullOrEmpty && longitude.isNotNullOrEmpty;

  bool get _showCall => phone.isNotNullOrEmpty && callVisible;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        SizedBox(
          height: context.screenHeight * 0.049,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppText(
              title,
              style: context.tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.cs.onSurface,
              ),
            ),
          ),
        ),
        if (name.isNotNullOrEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: ThemeConstants.paddingXS),
            child: AppText(
              name!,
              style: context.tt.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.cs.onSurface,
              ),
            ),
          ),
        if (phone.isNotNullOrEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 2),
            child: AppText(
              '${context.translate(LanguageLabelKeys.mobile)}: $phone',
              style: context.tt.labelMedium?.copyWith(
                color: context.cs.onSurfaceVariant,
              ),
            ),
          ),
        if (alternatePhone.isNotNullOrEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: ThemeConstants.paddingXS),
            child: AppText(
              '${context.translate(LanguageLabelKeys.alternateMobile)}: $alternatePhone',
              style: context.tt.labelMedium?.copyWith(
                color: context.cs.onSurfaceVariant,
              ),
            ),
          ),
        if (address.isNotNullOrEmpty)
          AppText(
            address!,
            style: context.tt.labelMedium?.copyWith(
              color: context.cs.onSurfaceVariant,
            ),
          ),
        if (_showCall || _hasCoordinates || onChatTap != null) ...[
          AppSpacing.h10,
          Row(
            children: [
              if (_showCall)
                _ActionChip(
                  icon: AssetsConstants.phoneIcon,
                  onTap: () => launchCall(phone),
                ),
              if (_showCall && onChatTap != null) AppSpacing.w10,
              if (onChatTap != null)
                _ActionChip(
                  icon: AssetsConstants.supportChatIcon,
                  onTap: onChatTap!,
                ),
              if ((_showCall || onChatTap != null) && _hasCoordinates)
                AppSpacing.w10,
              if (_hasCoordinates)
                Expanded(
                  child: _ActionChip(
                    icon: AssetsConstants.mapNavigationIcon,
                    label: context.translate(LanguageLabelKeys.getDirections),
                    onTap: () => launchDirection(latitude, longitude),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String icon;
  final String? label;
  final VoidCallback onTap;

  const _ActionChip({required this.icon, this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: AppDecorations.card(
          color: context.cs.primary.withValues(alpha: 0.14),
          borderRadius: AppRadius.r10,
        ),
        padding: label == null
            ? const EdgeInsetsDirectional.all(9)
            : const EdgeInsetsDirectional.symmetric(vertical: 9, horizontal: ThemeConstants.paddingXS),
        child: Row(
          mainAxisAlignment: .center,
          children: [
            AppSvgIcon(icon, size: ThemeConstants.iconS, color: context.cs.primary),
            if (label != null) ...[
              AppSpacing.w4,
              Flexible(
                child: AppText(
                  label!,
                  maxLines: 1,
                  overflow: .ellipsis,
                  style: context.tt.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.cs.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
