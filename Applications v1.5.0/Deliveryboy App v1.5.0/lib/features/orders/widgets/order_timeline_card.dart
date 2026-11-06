import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/features/orders/models/timeline_model.dart';
import 'package:deliveryboy/features/orders/widgets/order_status_timeline.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/show_app_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

/// Shadowed card wrapper around [OrderStatusTimeline] — shared by quick,
/// ecommerce, and return order-detail screens. Tapping the card opens a
/// bottom sheet with the full timeline.
class OrderTimelineCard extends StatelessWidget {
  final List<Timeline> timeline;
  final VoidCallback? onTrackOrder;
  const OrderTimelineCard({
    super.key,
    required this.timeline,
    this.onTrackOrder,
  });

  /// Shows current status + next status. If current is last status, shows
  /// last 2 (previous + current) since there is no "next" to show.
  List<Timeline> _buildPreviewList() {
    if (timeline.length <= 2) return timeline;

    final currentIndex = timeline.indexWhere((t) => t.isCurrent == true);
    if (currentIndex == -1) return timeline.sublist(timeline.length - 2);

    if (currentIndex >= timeline.length - 1) {
      return timeline.sublist(timeline.length - 2);
    }
    return timeline.sublist(currentIndex, currentIndex + 2);
  }

  void _showTimelineSheet(BuildContext context) {
    showAppBottomSheet(
      context,
      isScrollControlled: true,
      title: context.translate(LanguageLabelKeys.timeline),
      padding: const EdgeInsetsDirectional.fromSTEB(ThemeConstants.paddingXL, ThemeConstants.paddingL, ThemeConstants.paddingXL, 28),
      builder: (sheetCtx) {
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .start,
            children: [
              OrderStatusTimeline(statusList: timeline, animated: true),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final previewList = _buildPreviewList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingL),
      decoration: AppDecorations.shadowedCard(
        color: Theme.of(context).cardColor,
        shadowColor: context.cs.shadow,
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppText(
                  context.translate(LanguageLabelKeys.trackOrder),
                  style: context.tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.cs.onSurface,
                  ),
                ),
              ),
              if (onTrackOrder != null)
                _TrackOrderPillButton(onTap: onTrackOrder!),
            ],
          ),
          AppSpacing.h12,
          OrderStatusTimeline(statusList: previewList),
          if (timeline.length > 2) ...[
            AppSpacing.h6,
            InkWell(
              onTap: () => _showTimelineSheet(context),
              borderRadius: AppRadius.r8,
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: .center,
                  children: [
                    AppText(
                      context.translate(LanguageLabelKeys.seeMore),
                      style: context.tt.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.cs.primary,
                      ),
                    ),
                    AppSvgIcon(
                      AssetsConstants.arrowDownIcon,
                      color: context.cs.primary,
                      size: ThemeConstants.iconS,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrackOrderPillButton extends StatelessWidget {
  final VoidCallback onTap;
  const _TrackOrderPillButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.cs.primary.withValues(alpha: 0.1),
      borderRadius: AppRadius.r10,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.r10,
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          decoration: AppDecorations.card(
            borderRadius: AppRadius.r10,
            border: Border.all(
              color: context.cs.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: .min,
            children: [
              AppSvgIcon(
                AssetsConstants.enableLocationIcon,
                size: ThemeConstants.iconXS,
                color: context.cs.primary,
              ),
              AppSpacing.w4,
              AppText(
                context.translate(LanguageLabelKeys.trackOrder),
                style: context.tt.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.cs.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
