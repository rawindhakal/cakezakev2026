import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/favorite_button.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/services/deep_link_service.dart';
import 'package:customer/features/products/models/product_detail_model.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/constants/theme_constants.dart';

class ProductDetailCircleBtn extends StatelessWidget {
  final String icon;
  final VoidCallback onTap;
  final bool isActive;

  const ProductDetailCircleBtn({
    super.key,
    required this.icon,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isActive) {
      return IconButton(
        onPressed: onTap,
        icon: AppSvgIcon(
          icon,
          size: ThemeConstants.iconS,
          color: context.cs.onSurface,
          bakeTint: true,
        ),
        padding: EdgeInsetsDirectional.all(ThemeConstants.paddingS),
        visualDensity: VisualDensity.compact,
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        padding: EdgeInsetsDirectional.all(ThemeConstants.paddingS),
        decoration: AppDecorations.box(
          color: context.cs.surface.withValues(alpha: 0.9),
          shape: .circle,
          boxShadow: [
            BoxShadow(
              color: context.cs.scrim.withValues(alpha: 0.12),
              blurRadius: 8,
            ),
          ],
        ),
        child: AppSvgIcon(
          icon,
          size: ThemeConstants.iconS,
          color: context.cs.onSurface,
          bakeTint: true,
        ),
      ),
    );
  }
}

class ProductDetailShareBtn extends StatelessWidget {
  final ProductDetailDataModel product;
  final bool isActive;

  const ProductDetailShareBtn({
    super.key,
    required this.product,
    this.isActive = false,
  });

  void _onTap() {
    final name = product.name ?? '';
    final slug = product.slug ?? '';
    final url = DeepLinkService.instance.buildShareUrl(slug, name);
    SharePlus.instance.share(ShareParams(text: '$name\n\n$url'));
  }

  @override
  Widget build(BuildContext context) {
    if (isActive) {
      return IconButton(
        onPressed: _onTap,
        icon: AppSvgIcon(
          AssetsConstants.shareIcon,
          size: ThemeConstants.iconS,
          color: context.cs.onSurface,
          bakeTint: true,
          fit: BoxFit.scaleDown,
        ),
        padding: EdgeInsetsDirectional.zero,
        visualDensity: VisualDensity.compact,
      );
    }
    return GestureDetector(
      onTap: _onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: AppDecorations.box(
          color: context.cs.surface.withValues(alpha: 0.9),
          shape: .circle,
          boxShadow: [
            BoxShadow(
              color: context.cs.scrim.withValues(alpha: 0.12),
              blurRadius: 8,
            ),
          ],
        ),
        child: AppSvgIcon(
          AssetsConstants.shareIcon,
          size: ThemeConstants.iconS,
          color: context.cs.onSurface,
          bakeTint: true,
          fit: BoxFit.scaleDown,
        ),
      ),
    );
  }
}

class ProductDetailFavBtn extends StatelessWidget {
  final ProductDetailDataModel product;
  final bool isActive;

  const ProductDetailFavBtn({
    super.key,
    required this.product,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return FavoriteButton(
      productId: product.id?.toString(),
      initialIsFavorite: product.isFavorite ?? false,
      iconSize: 20,
      style: FavoriteButtonStyle.circle,
      isActive: isActive,
    );
  }
}
