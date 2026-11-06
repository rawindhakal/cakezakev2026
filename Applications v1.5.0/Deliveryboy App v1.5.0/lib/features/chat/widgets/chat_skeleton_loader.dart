import 'package:deliveryboy/commons/widgets/shimmer_builder.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';

/// Mirrors [ChatBubble]'s alternating left/right shape so the chat screen
/// doesn't jump layout once real message history swaps in while connecting.
class ChatSkeletonLoader extends StatelessWidget {
  final int itemCount;

  const ChatSkeletonLoader({super.key, this.itemCount = 8});

  Widget _bubble(BuildContext context, Color color, bool isMe, double width) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsetsDirectional.only(
          top: ThemeConstants.paddingXS,
          bottom: ThemeConstants.paddingXS,
          start: isMe ? 48 : 0,
          end: isMe ? 0 : 48,
        ),
        child: ShimmerBox(
          color,
          width: width,
          height: context.screenHeight * 0.049,
          radius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe
                ? const Radius.circular(16)
                : const Radius.circular(4),
            bottomRight: isMe
                ? const Radius.circular(4)
                : const Radius.circular(16),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = context.screenWidth * 0.72;
    final widths = [
      maxWidth * 0.7,
      maxWidth * 0.45,
      maxWidth * 0.6,
      maxWidth * 0.35,
    ];

    return ShimmerBuilder(
      builder: (context, color) => ListView.builder(
        padding: const EdgeInsetsDirectional.fromSTEB(ThemeConstants.paddingM, ThemeConstants.paddingM, ThemeConstants.paddingM, ThemeConstants.paddingS),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (_, index) =>
            _bubble(context, color, index.isOdd, widths[index % widths.length]),
      ),
    );
  }
}
