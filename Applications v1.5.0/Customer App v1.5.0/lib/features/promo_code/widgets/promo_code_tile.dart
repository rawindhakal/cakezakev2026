import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/loading_widget.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/promo_code/cubit/promo_code_validate_cubit.dart';
import 'package:customer/features/promo_code/models/enums/promo_discount_type.dart';
import 'package:customer/features/promo_code/models/promo_code_model.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';

class PromoCodeTileWidget extends StatefulWidget {
  final PromoCodeData item;
  final VoidCallback onApply;

  const PromoCodeTileWidget({
    super.key,
    required this.item,
    required this.onApply,
  });

  @override
  State<PromoCodeTileWidget> createState() => _PromoCodeTileWidgetState();
}

class _PromoCodeTileWidgetState extends State<PromoCodeTileWidget> {
  bool _expanded = false;
  final GlobalKey _cardKey = GlobalKey();
  final GlobalKey _dividerKey = GlobalKey();
  double? _notchDy;

  void _measureNotch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cardBox = _cardKey.currentContext?.findRenderObject() as RenderBox?;
      final dividerBox =
          _dividerKey.currentContext?.findRenderObject() as RenderBox?;
      if (cardBox == null || dividerBox == null) {
        if (_notchDy != null) setState(() => _notchDy = null);
        return;
      }
      final dividerOffset = dividerBox.localToGlobal(
        Offset(0, dividerBox.size.height / 2),
        ancestor: cardBox,
      );
      if (_notchDy != dividerOffset.dy) {
        setState(() => _notchDy = dividerOffset.dy);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isApplicable = item.isApplicable == 1;
    final discount = item.discount.toDouble();
    final hasImage = item.imageUrl.isNotEmpty && item.imageUrl != 'null';
    final title = item.title.isNotEmpty
        ? item.title
        : discount > 0
        ? '${discount.toStringAsFixed(discount.truncateToDouble() == discount ? 0 : 1)}${AppConstants.percentSymbol} ${context.translate(LanguageLabelKeys.off)}'
        : item.promoCode;

    final points = item.description
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final visiblePoints = _expanded ? points : points.take(2).toList();
    final hasMore = points.length > 2;

    final discountText = discount > 0
        ? (item.discountTypeEnum == PromoDiscountType.flat
              ? '${context.translate(LanguageLabelKeys.flatDiscount)} ${item.currency}${discount.toStringAsFixed(discount.truncateToDouble() == discount ? 0 : 1)} ${context.translate(LanguageLabelKeys.off)}'
              : '${discount.toStringAsFixed(discount.truncateToDouble() == discount ? 0 : 1)}${AppConstants.percentSymbol} ${context.translate(LanguageLabelKeys.off)}'
                    '${item.maxDiscountAmount > 0 ? ' (${context.translate(LanguageLabelKeys.maxDiscount)} ${item.currency}${item.maxDiscountAmount.toStringAsFixed(0)})' : ''}')
        : '';
    final noteLines = [
      discountText,
      item.unlockMessage,
      item.message,
    ].map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final hasNotch = noteLines.isNotEmpty;

    final topRow = Row(
      crossAxisAlignment: .center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: AppDecorations.box(
            color: context.cs.surfaceContainerHighest,
            borderRadius: AppRadius.r10,
          ),
          child: hasImage
              ? AppNetworkImage(url: item.imageUrl, borderRadius: AppRadius.r10)
              : AppSvgIcon(
                  AssetsConstants.offerIcon,
                  size: ThemeConstants.iconL,
                  color: context.cs.onSurfaceVariant.withValues(alpha: 0.4),
                  fit: BoxFit.scaleDown,
                ),
        ),
        AppSpacing.w12,
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            spacing: ThemeConstants.spaceXS,
            children: [
              AppText(
                title,
                style: context.tt.bodyLarge?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: context.cs.onSurface,
                ),
                maxLines: 1,
                overflow: .ellipsis,
              ),
              Text.rich(
                TextSpan(
                  style: context.tt.bodySmall?.copyWith(
                    color: context.cs.onSurfaceVariant,
                  ),
                  children: [
                    TextSpan(
                      text: '${context.translate(LanguageLabelKeys.useCode)} ',
                    ),
                    TextSpan(
                      text: item.promoCode,
                      style: context.tt.bodySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: .ellipsis,
              ),
            ],
          ),
        ),
        AppSpacing.w10,
        BlocSelector<PromoCodeValidateCubit, PromoCodeValidateState, bool>(
          selector: (state) =>
              state is PromoCodeValidateLoading &&
              state.promoCode == item.promoCode,
          builder: (context, isLoading) {
            return SizedBox(
              height: 30,
              child: FilledButton(
                onPressed: (!isApplicable || isLoading) ? null : widget.onApply,
                style: FilledButton.styleFrom(
                  backgroundColor: context.cs.primary,
                  disabledBackgroundColor: context.cs.primary.withValues(
                    alpha: 0.4,
                  ),
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: ThemeConstants.paddingL,
                  ),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.r8),
                ),
                child: isLoading
                    ? LoadingWidget(size: ThemeConstants.loaderSizeS)
                    : AppText(
                        context.translate(LanguageLabelKeys.apply),
                        style: context.tt.bodySmall?.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: context.cs.onPrimary,
                        ),
                      ),
              ),
            );
          },
        ),
      ],
    );

    final hasDivider = hasNotch || points.isNotEmpty;
    if (hasDivider) _measureNotch();

    final card = Container(
      key: _cardKey,
      padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingM),
      decoration: AppDecorations.shadowedCard(
        color: context.cs.surface,
        shadowColor: context.theme.shadowColor.withValues(alpha: 0.06),
        borderRadius: AppRadius.r16,
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          topRow,
          if (hasNotch) ...[
            AppSpacing.h12,
            _DashedDivider(key: _dividerKey, color: context.cs.outlineVariant),
            AppSpacing.h10,
            for (final note in noteLines) _BulletLine(text: note, fontSize: 11),
          ],
          if (points.isNotEmpty) ...[
            if (!hasNotch) ...[
              _DashedDivider(
                key: _dividerKey,
                color: context.cs.outlineVariant,
              ),
              AppSpacing.h10,
            ],
            for (final point in visiblePoints)
              _BulletLine(text: point, fontSize: 12),
            if (hasMore)
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: AppText(
                  _expanded
                      ? context.translate(LanguageLabelKeys.showLess)
                      : '+ ${context.translate(LanguageLabelKeys.readMore)}',
                  style: context.tt.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.cs.primary,
                  ),
                ),
              ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsetsDirectional.only(
        bottom: ThemeConstants.paddingM,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          if (hasDivider && _notchDy != null) ...[
            Positioned(
              left: -7,
              top: _notchDy! - 7,
              child: _NotchCircle(
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
            ),
            Positioned(
              right: -7,
              top: _notchDy! - 7,
              child: _NotchCircle(
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotchCircle extends StatelessWidget {
  const _NotchCircle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: AppDecorations.box(color: color, shape: .circle),
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine({required this.text, required this.fontSize});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        bottom: ThemeConstants.paddingXS,
      ),
      child: Row(
        crossAxisAlignment: .center,
        spacing: ThemeConstants.spaceXS,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: AppDecorations.box(
              color: context.cs.onSurfaceVariant,
              shape: .circle,
            ),
          ),
          Expanded(
            child: AppText(
              text,
              style: context.tt.bodySmall?.copyWith(
                fontSize: fontSize,
                color: context.cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const dashWidth = 4.0;
          const dashSpace = 3.0;
          final dashCount = (constraints.maxWidth / (dashWidth + dashSpace))
              .floor();
          return Row(
            children: List.generate(
              dashCount,
              (_) => Padding(
                padding: const EdgeInsetsDirectional.only(end: dashSpace),
                child: Container(width: dashWidth, height: 1, color: color),
              ),
            ),
          );
        },
      ),
    );
  }
}
