import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';

/// Backend `active_status` codes, named — one source of truth so a status
/// check reads as `activeStatus == OrderStatus.delivered` instead of a bare
/// magic number repeated across cubits/screens/widgets.
/// Ids 1,2,5,6,7,8 are shared by both channels; 3 (processed)/4 (shipped) only
/// occur for ecommerce orders; 9 (preparing)/10 (ready for pickup)/11 (pickup)
/// only for quick orders.
class OrderStatus {
  static const int paymentPending = 1;
  static const int orderReceived = 2;
  static const int processing = 3;
  static const int shipped = 4;
  static const int outForDelivery = 5;
  static const int delivered = 6;
  static const int cancelled = 7;
  static const int returned = 8;
  static const int preparing = 9;
  static const int readyForPickup = 10;
  static const int pickup = 11;
}

/// Maps backend `active_status` / timeline status codes to localized display names,
/// icons, and colors — one source of truth so status chips/icons look the same
/// on order cards, timelines, and detail screens.
/// Ids 1,2,5,6,7,8 are shared by both channels; 3 (processed)/4 (shipped) only
/// occur for ecommerce orders; 9 (preparing)/10 (ready for pickup)/11 (pickup)
/// only for quick orders.
class OrderStatusLabels {
  static String name(BuildContext context, int? code) {
    return switch (code) {
      OrderStatus.paymentPending => context.translate(
        LanguageLabelKeys.statusPaymentPending,
      ),
      OrderStatus.orderReceived => context.translate(
        LanguageLabelKeys.statusOrderReceived,
      ),
      OrderStatus.processing => context.translate(
        LanguageLabelKeys.statusProcessing,
      ),
      OrderStatus.shipped => context.translate(LanguageLabelKeys.statusShipped),
      OrderStatus.outForDelivery => context.translate(
        LanguageLabelKeys.statusOutForDelivery,
      ),
      OrderStatus.delivered => context.translate(
        LanguageLabelKeys.statusDelivered,
      ),
      OrderStatus.cancelled => context.translate(
        LanguageLabelKeys.statusCancelled,
      ),
      OrderStatus.returned => context.translate(
        LanguageLabelKeys.statusReturned,
      ),
      OrderStatus.preparing => context.translate(
        LanguageLabelKeys.statusPreparing,
      ),
      OrderStatus.readyForPickup => context.translate(
        LanguageLabelKeys.statusReadyForPickup,
      ),
      OrderStatus.pickup => context.translate(LanguageLabelKeys.statusPickup),
      _ => context.translate(LanguageLabelKeys.statusUnknown),
    };
  }

  static String icon(int? code) {
    return switch (code) {
      OrderStatus.paymentPending => AssetsConstants.orderPaymentPendingIcon,
      OrderStatus.orderReceived => AssetsConstants.orderReceivedIcon,
      OrderStatus.processing => AssetsConstants.orderPendingIcon,
      OrderStatus.shipped => AssetsConstants.orderOutForDeliveryIcon,
      OrderStatus.outForDelivery => AssetsConstants.orderOutForDeliveryIcon,
      OrderStatus.delivered => AssetsConstants.orderDeliveredIcon,
      OrderStatus.cancelled => AssetsConstants.orderCancelledIcon,
      OrderStatus.returned => AssetsConstants.orderReturnIcon,
      OrderStatus.preparing => AssetsConstants.orderPendingIcon,
      OrderStatus.readyForPickup => AssetsConstants.orderReadyForPickupIcon,
      OrderStatus.pickup => AssetsConstants.orderReadyForPickupIcon,
      _ => AssetsConstants.orderUnknownIcon,
    };
  }

  static Color color(BuildContext context, int? code) {
    return switch (code) {
      OrderStatus.delivered => context.cs.onSecondaryContainer,
      OrderStatus.returned => context.cs.onSecondaryContainer,
      OrderStatus.cancelled => context.cs.error,
      _ => context.cs.errorContainer,
    };
  }
}
