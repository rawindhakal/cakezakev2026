import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';

/// Maps backend `active_status` / timeline status codes to localized display names,
/// icons, and colors — one source of truth so status chips/icons look the same
/// on order cards, timelines, and detail screens.
/// Ids 1,2,5,6,7,8 are shared by both channels; 3 (processed)/4 (shipped) only
/// occur for ecommerce orders; 9 (preparing)/10 (ready for pickup)/11 (pickup)
/// only for quick orders.
class OrderStatusLabels {
  static String name(BuildContext context, int? code) {
    return switch (code) {
      1 => context.translate(LanguageLabelKeys.statusPaymentPending),
      2 => context.translate(LanguageLabelKeys.statusOrderReceived),
      3 => context.translate(LanguageLabelKeys.statusProcessing),
      4 => context.translate(LanguageLabelKeys.statusShipped),
      5 => context.translate(LanguageLabelKeys.statusOutForDelivery),
      6 => context.translate(LanguageLabelKeys.statusDelivered),
      7 => context.translate(LanguageLabelKeys.statusCancelled),
      8 => context.translate(LanguageLabelKeys.statusReturned),
      9 => context.translate(LanguageLabelKeys.statusPreparing),
      10 => context.translate(LanguageLabelKeys.statusReadyForPickup),
      11 => context.translate(LanguageLabelKeys.statusPickup),
      _ => context.translate(LanguageLabelKeys.statusUnknown),
    };
  }

  static String icon(int? code) {
    return switch (code) {
      1 => AssetsConstants.orderPaymentPendingIcon,
      2 => AssetsConstants.orderReceivedIcon,
      3 => AssetsConstants.orderPendingIcon,
      4 => AssetsConstants.orderOutForDeliveryIcon,
      5 => AssetsConstants.orderOutForDeliveryIcon,
      6 => AssetsConstants.orderDeliveredIcon,
      7 => AssetsConstants.orderCancelledIcon,
      8 => AssetsConstants.orderReturnIcon,
      9 => AssetsConstants.orderPendingIcon,
      10 => AssetsConstants.orderReadyForPickupIcon,
      11 => AssetsConstants.orderReadyForPickupIcon,
      _ => AssetsConstants.orderUnknownIcon,
    };
  }

  static Color color(BuildContext context, int? code) {
    return switch (code) {
      1 => context.cs.errorContainer,
      2 => context.cs.primaryFixedDim,
      3 => context.cs.inversePrimary,
      4 => context.cs.tertiaryContainer,
      5 => context.cs.inversePrimary,
      6 => context.cs.onSecondaryContainer,
      7 => context.cs.onErrorContainer,
      8 => context.cs.onSecondaryFixed,
      9 => context.cs.errorContainer,
      10 => context.cs.inversePrimary,
      11 => context.cs.inversePrimary,
      _ => context.cs.errorContainer,
    };
  }
}
