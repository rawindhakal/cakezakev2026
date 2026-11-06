import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/features/products/models/product_model.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/core/constants/theme_constants.dart';

class ViewMoreButton extends StatelessWidget {
  final List<ProductDataModel> products;
  final int shownCount;
  final VoidCallback onTap;

  /// When provided (e.g. home builder blocks), thumbnails and visibility are
  /// driven by this list instead of [products] — empty list hides the button.
  final List<String>? previewImageUrls;

  /// Left/right margin. Defaults to [ThemeConstants.paddingL]; callers that
  /// wrap product listings with a different horizontal padding can pass it
  /// here to keep the button aligned with the listing above it.
  final double? horizontalMargin;

  /// Overrides the default "View More" label.
  final String? label;

  const ViewMoreButton({
    super.key,
    required this.products,
    this.shownCount = 6,
    required this.onTap,
    this.previewImageUrls,
    this.horizontalMargin,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    if (previewImageUrls != null && previewImageUrls!.isEmpty) {
      return const SizedBox.shrink();
    }

    final previews =
        (previewImageUrls ??
                products.skip(shownCount).map((p) => p.images?.coverUrl ?? ''))
            .take(3)
            .toList();
    final stackWidth = previews.isEmpty
        ? 0.0
        : (previews.length - 1) * 18.0 + 30.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsetsDirectional.fromSTEB(
          horizontalMargin ?? ThemeConstants.paddingL,
          ThemeConstants.paddingXS,
          horizontalMargin ?? ThemeConstants.paddingL,
          ThemeConstants.paddingL,
        ),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ThemeConstants.paddingL,
          vertical: ThemeConstants.paddingS,
        ),
        decoration: AppDecorations.box(
          color: context.cs.surfaceContainerHigh,
          borderRadius: AppRadius.r8,
          border: Border.all(color: context.cs.outline, width: 1),
        ),
        child: Row(
          mainAxisAlignment: .center,
          children: [
            if (previews.isNotEmpty) ...[
              SizedBox(
                width: stackWidth,
                height: 30,
                child: Stack(
                  children: List.generate(
                    previews.length,
                    (i) => PositionedDirectional(
                      start: i * 18.0,
                      child: _Thumb(imageUrl: previews[i]),
                    ),
                  ),
                ),
              ),
              AppSpacing.w8,
            ],
            AppText(
              label ?? context.translate(LanguageLabelKeys.viewMore),
              style: context.tt.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.cs.onSurface,
              ),
            ),
            AppSpacing.w4,
            Transform.flip(
              flipX: Directionality.of(context) == TextDirection.rtl,
              child: AppSvgIcon(
                AssetsConstants.arrowRightIcon,
                size: ThemeConstants.iconM,
                color: context.cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String imageUrl;
  const _Thumb({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: AppDecorations.box(
        shape: .circle,
        border: Border.all(color: context.cs.surface, width: 1.5),
        color: context.cs.surfaceContainerHighest,
      ),
      child: ClipOval(
        child: AppNetworkImage(
          url: imageUrl,
          errorWidget: ColoredBox(color: context.cs.surfaceContainerHigh),
        ),
      ),
    );
  }
}
