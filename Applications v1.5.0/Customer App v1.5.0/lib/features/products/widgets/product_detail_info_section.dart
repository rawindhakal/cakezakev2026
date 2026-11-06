import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/products/models/product_detail_model.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/constants/theme_constants.dart';

String _daysText(BuildContext context, int days) =>
    '$days ${context.translate(days == 1 ? LanguageLabelKeys.day : LanguageLabelKeys.days)}';

class ProductDetailInfoTable extends StatelessWidget {
  final ProductDetailDataModel product;

  const ProductDetailInfoTable({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final rows = <({String label, String value})>[];

    bool valid(String? v) =>
        v != null && v.isNotEmpty && v != 'null' && v != '0';

    if (valid(product.branchName)) {
      rows.add((
        label: context.translate(LanguageLabelKeys.soldBy),
        value: product.branchName!,
      ));
    }
    if (valid(product.categoryName)) {
      rows.add((
        label: context.translate(LanguageLabelKeys.category),
        value: product.categoryName!,
      ));
    }
    if (valid(product.brandName)) {
      rows.add((
        label: context.translate(LanguageLabelKeys.brand),
        value: product.brandName!,
      ));
    }
    if (valid(product.manufacturer)) {
      rows.add((
        label: context.translate(LanguageLabelKeys.manufacturer),
        value: product.manufacturer!,
      ));
    }
    final madeInName = product.madeIn;
    if (valid(madeInName)) {
      rows.add((
        label: context.translate(LanguageLabelKeys.madeIn),
        value: madeInName!,
      ));
    }
    if ((product.taxIncludedInPrice ?? 0) == 1) {
      rows.add((
        label: context.translate(LanguageLabelKeys.tax),
        value: context.translate(LanguageLabelKeys.includedInPrice),
      ));
    }
    if ((product.returnStatus ?? 0) == 1 && (product.returnDays ?? 0) > 0) {
      rows.add((
        label: context.translate(LanguageLabelKeys.returnPolicy),
        value: _daysText(context, product.returnDays!),
      ));
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      children: List.generate(rows.length, (i) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: ThemeConstants.paddingL,
                vertical: ThemeConstants.paddingS,
              ),
              child: Row(
                crossAxisAlignment: .start,
                children: [
                  SizedBox(
                    width: 130,
                    child: AppText(
                      rows[i].label,
                      style: context.tt.bodySmall?.copyWith(
                        color: context.cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: AppText(
                      rows[i].value,
                      style: context.tt.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (i < rows.length - 1)
              Divider(
                color: context.cs.outlineVariant,
                height: 1,
                indent: 16,
                endIndent: 16,
              ),
          ],
        );
      }),
    );
  }
}

class ProductDetailPoliciesSection extends StatelessWidget {
  final ProductDetailDataModel product;

  const ProductDetailPoliciesSection({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    bool on(int? v) => v == 1;

    final returnOn = on(product.returnStatus);
    final codOn = on(product.codAllowed);
    final cancelOn = on(product.cancelableStatus);
    final days = product.returnDays ?? 0;

    final policies =
        <({String icon, String title, String subtitle, bool available})>[
          (
            icon: AssetsConstants.returnOrderIcon,
            title: returnOn
                ? (days > 0
                      ? _daysText(context, days)
                      : context.translate(LanguageLabelKeys.easyReturns))
                : context.translate(LanguageLabelKeys.returnNotAvailable),
            subtitle: returnOn
                ? context.translate(LanguageLabelKeys.returnsAvailable)
                : context.translate(LanguageLabelKeys.returnUnavailable),
            available: returnOn,
          ),
          (
            icon: AssetsConstants.codOrderIcon,
            title: codOn
                ? context.translate(LanguageLabelKeys.cashOnDelivery)
                : context.translate(LanguageLabelKeys.codNotAvailable),
            subtitle: codOn
                ? context.translate(LanguageLabelKeys.payAtDoorstep)
                : context.translate(LanguageLabelKeys.codUnavailable),
            available: codOn,
          ),
          (
            icon: cancelOn
                ? AssetsConstants.cancelOrderIcon
                : AssetsConstants.notCancelOrderIcon,
            title: cancelOn
                ? context.translate(LanguageLabelKeys.cancellable)
                : context.translate(LanguageLabelKeys.notCancellable),
            subtitle: cancelOn
                ? context.translate(LanguageLabelKeys.cancelBeforeDispatch)
                : context.translate(LanguageLabelKeys.cannotBeCancelled),
            available: cancelOn,
          ),
        ];

    final dividerColor = context.cs.outlineVariant;

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: ThemeConstants.paddingL,
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < policies.length; i++) ...[
              if (i > 0)
                VerticalDivider(
                  width: 16,
                  thickness: 1,
                  indent: 6,
                  endIndent: 6,
                  color: dividerColor,
                ),
              Expanded(child: _PolicyItem(policy: policies[i])),
            ],
          ],
        ),
      ),
    );
  }
}

class _PolicyItem extends StatelessWidget {
  final ({String icon, String title, String subtitle, bool available}) policy;
  const _PolicyItem({required this.policy});

  @override
  Widget build(BuildContext context) {
    final p = policy;
    return Column(
      crossAxisAlignment: .center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: AppDecorations.box(
            color: p.available
                ? context.cs.primary.withValues(alpha: 0.1)
                : context.cs.surfaceContainerHighest,
            borderRadius: AppRadius.r12,
          ),
          padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingS),
          child: AppSvgIcon(
            p.icon,
            size: ThemeConstants.iconS,
            useColorMapper: true,
            color: context.cs.primary,
          ),
        ),
        AppSpacing.h6,
        AppText(
          p.title,
          style: context.tt.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: p.available
                ? context.cs.onSurface
                : context.cs.onSurfaceVariant,
          ),
          textAlign: .center,
          maxLines: 1,
          overflow: .ellipsis,
        ),
        AppSpacing.h1,
        AppText(
          p.subtitle,
          style: context.tt.labelSmall?.copyWith(
            fontSize: 10,
            color: context.cs.onSurfaceVariant,
          ),
          textAlign: .center,
          maxLines: 1,
          overflow: .ellipsis,
        ),
      ],
    );
  }
}

class KeyFeaturesSection extends StatelessWidget {
  final ProductDetailDataModel product;

  const KeyFeaturesSection({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final features = <({String label, String value})>[];

    bool valid(String? v) => v != null && v.isNotEmpty && v != 'null';

    if (valid(product.categoryName)) {
      features.add((
        label: context.translate(LanguageLabelKeys.category),
        value: product.categoryName!,
      ));
    }
    if (valid(product.brandName)) {
      features.add((
        label: context.translate(LanguageLabelKeys.brand),
        value: product.brandName!,
      ));
    }
    final madeInName = product.madeIn;
    if (valid(madeInName)) {
      features.add((
        label: context.translate(LanguageLabelKeys.madeIn),
        value: madeInName!,
      ));
    }
    if (valid(product.branchName)) {
      features.add((
        label: context.translate(LanguageLabelKeys.soldBy),
        value: product.branchName!,
      ));
    }

    if (features.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        ThemeConstants.paddingL,
        ThemeConstants.paddingM,
        ThemeConstants.paddingL,
        ThemeConstants.paddingM,
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          AppText(
            context.translate(LanguageLabelKeys.keyFeatures),
            style: context.tt.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.cs.onSurface,
            ),
          ),
          AppSpacing.h10,
          ...List.generate(features.length, (i) {
            final f = features[i];
            return Padding(
              padding: const EdgeInsetsDirectional.only(
                bottom: ThemeConstants.paddingS,
              ),
              child: Row(
                crossAxisAlignment: .start,
                children: [
                  SizedBox(
                    width: 80,
                    child: AppText(
                      f.label,
                      style: context.tt.bodySmall?.copyWith(
                        color: context.cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: AppText(
                      f.value,
                      style: context.tt.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
