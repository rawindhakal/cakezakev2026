import 'dart:io';
import 'package:deliveryboy/commons/widgets/profile_avatar_picker.dart';
import 'package:flutter/material.dart';

/// Fades and shrinks [child] as [controller] scrolls toward [collapseOffset].
/// Pairs with `CustomAppBar.collapsedLeading`, which grows in beside the title
/// over the same range; scrolling back down reverses both.
class CollapseOnScroll extends StatelessWidget {
  final ScrollController controller;
  final double collapseOffset;
  final Widget child;

  const CollapseOnScroll({
    super.key,
    required this.controller,
    required this.collapseOffset,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = controller.hasClients
            ? (controller.offset / collapseOffset).clamp(0.0, 1.0)
            : 0.0;
        return Opacity(
          opacity: 1 - t,
          child: Transform.scale(scale: 1 - 0.4 * t, child: child),
        );
      },
      child: child,
    );
  }
}

/// Compact, tappable avatar picker (with camera badge) shown in the app bar
/// once the body avatar collapses.
class CollapsedAvatar extends StatelessWidget {
  final File? image;
  final String? imageUrl;
  final ValueChanged<File> onPicked;

  const CollapsedAvatar({
    super.key,
    required this.onPicked,
    this.image,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileAvatarPicker(
      size: 38,
      compact: true,
      image: image,
      imageUrl: imageUrl,
      onPicked: onPicked,
    );
  }
}
