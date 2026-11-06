import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/features/home/models/home_builder_model.dart';
import 'package:customer/features/home/utils/home_redirect_handler.dart';
import 'package:customer/features/home/utils/responsive_height_helper.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';

class TitleImage extends StatelessWidget {
  final Blocks block;
  const TitleImage({super.key, required this.block});

  String? _imageUrl(BuildContext context) {
    final width = context.screenWidth;
    final isTablet = width >= 600;

    final imgs = block.images;
    if (imgs != null) {
      if (isTablet) {
        final tablet = imgs.tablet;
        if (tablet != null && tablet.isNotEmpty) return tablet;
      } else {
        final app = imgs.app;
        if (app != null && app.isNotEmpty) return app;
      }
    }
    return block.imageUrl?.isNotEmpty == true ? block.imageUrl : null;
  }

  void _handleTap(BuildContext context) {
    handleHomeRedirectTap(
      context,
      redirectType: block.redirectType,
      redirectId: block.redirectId,
      redirectUrl: block.redirectUrl,
      redirectSlug: block.redirectSlug,
      redirectTitle: block.redirectTitle,
      redirectParams: block.redirectParams,
      hasChild: block.hasChild,
      skipUrlWhenTypeNone: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = _imageUrl(context);
    if (url == null) return const SizedBox.shrink();

    final placeholderColor = context.isDark
        ? context.cs.outline
        : context.cs.outline;
    // Placeholder-only guess for the loading flash — the real image below
    // ignores this and sizes itself from its own decoded dimensions
    // (width fixed, height left null), so it always shows uncropped and
    // ungapped regardless of what imageAspect (or a mismatched per-device
    // upload) says.
    final placeholderHeight = ResponsiveHeightHelper.calculateFromAspect(
      imageAspect: block.config?.imageAspect?.resolve(
        context.screenWidth >= 600,
      ),
      context: context,
    );

    return GestureDetector(
      onTap: () => _handleTap(context),
      child: AppNetworkImage(
        url: url,
        width: double.infinity,
        fit: BoxFit.fitWidth,
        placeholder: SizedBox(
          height: placeholderHeight,
          child: ColoredBox(color: placeholderColor),
        ),
        errorWidget: SizedBox(
          height: placeholderHeight,
          child: ColoredBox(color: placeholderColor),
        ),
      ),
    );
  }
}
