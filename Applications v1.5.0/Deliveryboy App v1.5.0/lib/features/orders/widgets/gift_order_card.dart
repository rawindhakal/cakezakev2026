import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';

/// Gift details of an order: recipient, when to deliver, card message.
class GiftOrderCard extends StatelessWidget {
  final dynamic order;
  const GiftOrderCard({super.key, required this.order});

  static bool hasGift(dynamic o) =>
      (o?.recipientName?.toString().isNotEmpty ?? false) ||
      (o?.giftMessage?.toString().isNotEmpty ?? false) ||
      (o?.giftDeliveryDate?.toString().isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      if ((order.recipientName ?? '').isNotEmpty)
        'To: ${order.recipientName}${(order.recipientRelationship ?? '').isNotEmpty ? ' (${order.recipientRelationship})' : ''}${(order.recipientPhone ?? '').isNotEmpty ? ' · ${order.recipientPhone}' : ''}',
      if ((order.senderName ?? '').isNotEmpty) 'From: ${order.senderName}',
      if ((order.occasion ?? '').isNotEmpty) 'Occasion: ${order.occasion}',
      if ((order.giftDeliveryDate ?? '').isNotEmpty)
        'Deliver on: ${order.giftDeliveryDate}${(order.deliverySlot ?? '').isNotEmpty ? ' · ${order.deliverySlot}' : ''}${(order.giftDeliveryType ?? '').isNotEmpty ? ' · ${order.giftDeliveryType}' : ''}',
      if ((order.personalization ?? '').isNotEmpty) 'Personalisation: ${order.personalization}',
      if ((order.giftMessage ?? '').isNotEmpty) 'Card message: "${order.giftMessage}"',
    ];
    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: ThemeConstants.paddingL),
      padding: const EdgeInsetsDirectional.all(14),
      decoration: AppDecorations.shadowedCard(
        color: Theme.of(context).cardColor,
        shadowColor: context.cs.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            '🎁 Gift details${order.isSurprise ? '  ·  SURPRISE' : ''}',
            style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: AppText(l, style: context.tt.labelMedium),
            ),
        ],
      ),
    );
  }
}
