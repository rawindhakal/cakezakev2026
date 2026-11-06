import 'package:deliveryboy/commons/widgets/gift_box_loader.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';

/// Loading indicator. With no [size] it is the gift-box animation used for pages and lists; with a small
/// explicit [size] (buttons, inline status) it stays a compact spinner so layouts do not change.
class LoadingWidget extends StatelessWidget {
  final double? size;
  final Color? color;

  const LoadingWidget({super.key, this.size, this.color});

  @override
  Widget build(BuildContext context) {
    final s = size;
    if (s == null || s >= 40) {
      return Center(child: GiftBoxLoader(size: s ?? 72, color: color));
    }
    return Center(
      child: SizedBox(
        width: s,
        height: s,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: color ?? context.cs.primary,
        ),
      ),
    );
  }
}
