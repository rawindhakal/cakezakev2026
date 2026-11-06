import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/features/cart/models/delivery_type.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';

/// AppBar-trailing pill toggle switching between [DeliveryType] values,
/// matching the Delivery/Pick-Up segmented control on the checkout screen
/// mock: the active side shows icon + label on a filled pill (with a slight
/// bounce as it expands), the inactive side collapses to just its icon.
class CheckoutDeliveryTypeToggle extends StatelessWidget {
  final DeliveryType type;
  final ValueChanged<DeliveryType> onChanged;

  const CheckoutDeliveryTypeToggle({
    super.key,
    required this.type,
    required this.onChanged,
  });

  // Gap between the selected pill and the toggle's top/bottom border.
  static const double _verticalInset = 6;

  // Swipe right (positive velocity) -> pickup (right segment); swipe left ->
  // delivery (left segment). A flick that doesn't clear the velocity
  // threshold is ignored so a stray drag doesn't flip the selection.
  void _onHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 100) return;
    final target = velocity > 0 ? DeliveryType.pickup : DeliveryType.delivery;
    if (target != type) onChanged(target);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Container(
        height: 40,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ThemeConstants.paddingXS,
          vertical: _verticalInset,
        ),
        decoration: AppDecorations.box(
          color: context.cs.surfaceContainerHighest,
          borderRadius: AppRadius.pill,
          border: Border.all(color: context.cs.outline, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Segment(
              icon: AssetsConstants.orderIcon,
              label: context.translate(LanguageLabelKeys.delivery),
              selected: type == DeliveryType.delivery,
              onTap: () => onChanged(DeliveryType.delivery),
            ),
            _Segment(
              icon: AssetsConstants.cartIcon,
              label: context.translate(LanguageLabelKeys.pickUp),
              selected: type == DeliveryType.pickup,
              onTap: () => onChanged(DeliveryType.pickup),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatefulWidget {
  final String icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Segment({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_Segment> createState() => _SegmentState();
}

class _SegmentState extends State<_Segment> {
  // Quick press-down/release scale so tapping a segment gives tactile
  // bounce feedback on top of the expand/collapse transition below.
  double _scale = 1;

  void _setPressed(bool pressed) => setState(() => _scale = pressed ? 0.9 : 1);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: widget.selected
                ? ThemeConstants.spaceM
                : ThemeConstants.spaceS,
          ),
          decoration: BoxDecoration(
            color: widget.selected ? Colors.black : Colors.transparent,
            borderRadius: AppRadius.pill,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppSvgIcon(
                widget.icon,
                size: ThemeConstants.iconS,
                color: widget.selected
                    ? context.cs.onPrimary
                    : context.cs.onSurfaceVariant,
              ),
              ClipRect(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  child: !widget.selected
                      ? const SizedBox.shrink()
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: ThemeConstants.spaceXS),
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 320),
                              curve: Curves.easeOutCubic,
                              opacity: widget.selected ? 1 : 0,
                              child: AppText(
                                widget.label,
                                style: context.tt.labelMedium?.copyWith(
                                  color: context.cs.onPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
