import 'package:customer/commons/widgets/shimmer_builder.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';

/// Mirrors [ChatBubble]'s alternating left/right shape so the chat screen
/// doesn't jump layout once real message history swaps in while connecting.
class ChatSkeletonLoader extends StatelessWidget {
  final int itemCount;

  const ChatSkeletonLoader({super.key, this.itemCount = 8});

  Widget _bubble(BuildContext context, Color color, bool isMe, double width) {
    return Align(
      alignment: isMe
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
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
          height: 40,
          radius: BorderRadiusDirectional.only(
            topStart: AppRadius.lg,
            topEnd: AppRadius.lg,
            bottomStart: isMe ? AppRadius.lg : AppRadius.xs,
            bottomEnd: isMe ? AppRadius.xs : AppRadius.lg,
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
        padding: const EdgeInsetsDirectional.fromSTEB(
          ThemeConstants.paddingM,
          ThemeConstants.paddingM,
          ThemeConstants.paddingM,
          ThemeConstants.paddingS,
        ),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (_, index) =>
            _bubble(context, color, index.isOdd, widths[index % widths.length]),
      ),
    );
  }
}
