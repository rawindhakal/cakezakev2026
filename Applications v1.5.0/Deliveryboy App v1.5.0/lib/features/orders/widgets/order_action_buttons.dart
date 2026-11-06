import 'dart:io';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';

import '../../../commons/widgets/app_text.dart';

import 'package:deliveryboy/core/configs/app_config.dart';
import 'package:deliveryboy/core/constants/navigation_service.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/routes/route_names.dart';
import 'package:deliveryboy/features/orders/models/order_detail_model.dart'
    as detail_model
    show Order;
import 'package:deliveryboy/features/orders/models/order_status.dart';
import 'package:deliveryboy/features/orders/screens/order_tracking_screen.dart'
    show OrderTrackingArgs;
import 'package:deliveryboy/core/utils/app_logger.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';

Future<void> launchCall(String? mobile) async {
  if (mobile == null || mobile.isEmpty || mobile == 'null') return;
  final uri = Uri(scheme: 'tel', path: mobile);
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}

Future<void> launchDirection(String? lat, String? lng) async {
  Uri uri;
  if (Platform.isAndroid) {
    uri = Uri.parse("${AppConfig.androidNavigationUrl}$lat,$lng");
  } else if (Platform.isIOS) {
    uri = Uri.parse("${AppConfig.appleMapsDirectionUrl}$lat,$lng");
  } else {
    uri = Uri.parse("${AppConfig.googleMapsDirectionUrl}$lat,$lng");
  }
  try {
    final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!success) throw "Could not launch map";
  } catch (e) {
    logDebug(() => "Map launch error: $e");
  }
}

void openOrderTracking(BuildContext context, detail_model.Order? order) {
  if (order == null) return;
  AppNavigator.pushNamed(
    context,
    RouteNames.orderTracking,
    arguments: OrderTrackingArgs(
      addressLatitude: double.tryParse(order.address?.latitude ?? '0') ?? 0.0,
      addressLongitude: double.tryParse(order.address?.longitude ?? '0') ?? 0.0,
      address: order.address?.address ?? '—',
      orderId: order.orderId?.toString() ?? '',
      customerName: order.address?.name ?? order.userName ?? '—',
      customerNumber: order.address?.mobile ?? order.userMobile ?? '—',
      customerAlternateNumber: order.address?.alternateMobile,
      customerId: order.userId ?? 0,
      chatVisible: order.isDeliveryBoyChatVisible == true,
      orderStatus: order.activeStatus,
      storeLatitude: double.tryParse(order.storeInfo?.latitude ?? ''),
      storeLongitude: double.tryParse(order.storeInfo?.longitude ?? ''),
      storeName: order.storeInfo?.storeName,
      storeAddress: order.storeInfo?.formattedAddress,
      storeNumber: order.storeInfo?.mobile,
    ),
  );
}

class OrderActionButtons extends StatelessWidget {
  final detail_model.Order? order;
  const OrderActionButtons({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final showTrack = OrderStatus.isTrackable(order?.activeStatus);
    return Column(
      children: [
        Row(
          children: [
            _ActionTile(
              icon: AssetsConstants.phoneIcon,
              label: context.translate(LanguageLabelKeys.callCustomerLabel),
              color: context.cs.primary,
              bgColor: context.cs.primaryContainer,
              onTap: () => launchCall(order?.userMobile),
            ),
            AppSpacing.w10,
            _ActionTile(
              icon: AssetsConstants.storeIcon,
              label: context.translate(LanguageLabelKeys.callSellerLabel),
              color: context.cs.primary,
              bgColor: context.cs.primaryContainer,
              onTap: () => launchCall(order?.mobile),
            ),
            AppSpacing.w10,
            _ActionTile(
              icon: AssetsConstants.mapNavigationIcon,
              label: context.translate(
                LanguageLabelKeys.customerDirectionLabel,
              ),
              color: context.cs.inversePrimary,
              bgColor: context.cs.secondaryContainer.withValues(alpha: 0.12),
              onTap: () => launchDirection(
                order?.address?.latitude,
                order?.address?.longitude,
              ),
            ),
            AppSpacing.w10,
            _ActionTile(
              icon: AssetsConstants.mapIcon,
              label: context.translate(LanguageLabelKeys.sellerDirectionLabel),
              color: context.cs.inversePrimary,
              bgColor: context.cs.secondaryContainer.withValues(alpha: 0.12),
              onTap: () =>
                  launchDirection(order?.storeLatitude, order?.storeLongitude),
            ),
          ],
        ),
        if (showTrack) ...[
          AppSpacing.h10,
          SizedBox(
            width: double.infinity,
            child: _ActionTile(
              icon: AssetsConstants.enableLocationIcon,
              label: context.translate(LanguageLabelKeys.trackOrder),
              color: context.cs.primary,
              bgColor: context.cs.errorContainer.withValues(alpha: 0.12),
              onTap: () => openOrderTracking(context, order),
              fullWidth: true,
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;
  final bool fullWidth;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    if (fullWidth) {
      return Material(
        color: bgColor,
        borderRadius: AppRadius.r14,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.r14,
          child: Container(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 14),
            decoration: AppDecorations.card(
              borderRadius: AppRadius.r14,
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: .center,
              children: [
                AppSvgIcon(icon, size: ThemeConstants.iconS, color: color),
                AppSpacing.w8,
                AppText(
                  label,
                  style: context.tt.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Expanded(
      child: Material(
        color: bgColor,
        borderRadius: AppRadius.r14,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.r14,
          child: Container(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 14),
            decoration: AppDecorations.card(
              borderRadius: AppRadius.r14,
              border: Border.all(color: color.withValues(alpha: 0.15)),
            ),
            child: Column(
              mainAxisSize: .min,
              children: [
                Container(
                  width: context.screenWidth * 0.107,
                  height: context.screenWidth * 0.107,
                  decoration: AppDecorations.circle(
                    color: color.withValues(alpha: 0.15),
                  ),
                  child: AppSvgIcon(icon, size: ThemeConstants.iconS, color: color),
                ),
                AppSpacing.h8,
                AppText(
                  label,
                  textAlign: .center,
                  style: context.tt.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
