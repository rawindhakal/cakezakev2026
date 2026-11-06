import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:flutter/material.dart';

/// Compact bar docked under the app bar. Fades in once the full header
/// (summary card, action button, …) at the top of a list has scrolled out of
/// view, so it stays reachable while browsing (same idea as checkout's pinned
/// "you saved" bar). Place it in a [Stack] over the list; hidden while
/// [hidden] is true.
///
/// Default layout is icon + [label] + [amountText] (or a custom [trailing]);
/// pass [content] to replace it entirely. Pass [onTap] to make the bar
/// tappable.
class StickyBar extends StatelessWidget {
  const StickyBar({
    super.key,
    required this.controller,
    required this.label,
    this.amountText,
    this.trailing,
    this.iconAsset = AssetsConstants.walletIcon,
    this.onTap,
    this.hidden = false,
  });

  final ScrollController controller;
  final String label;
  final String? amountText;
  final Widget? trailing;
  final String iconAsset;
  final VoidCallback? onTap;
  final bool hidden;

  // Roughly the summary card's main-row height: bar starts appearing once
  // the card is mostly scrolled away and is fully shown after _fadeRange.
  static const double showAfter = 60;
  static const double _fadeRange = 40;
  static const double _barHeight = 52;

  /// Whether the bar is (even partly) showing at [offset].
  static bool isVisibleAt(double offset) => offset > showAfter;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final offset = controller.hasClients ? controller.offset : 0.0;
        final progress = ((offset - showAfter) / _fadeRange).clamp(0.0, 1.0);
        if (hidden || progress <= 0) return const SizedBox.shrink();

        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, -_barHeight * (1 - progress) * 0.3),
            child: Container(
              decoration: BoxDecoration(
                // Opaque blend so list rows don't show through.
                color: Color.alphaBlend(
                  context.cs.primary.withValues(alpha: 0.10),
                  context.cs.surface,
                ),
                boxShadow: [
                  BoxShadow(
                    color: context.cs.shadow.withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onTap,
                  child: Container(
                    height: _barHeight,
                    width: double.infinity,
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: ThemeConstants.paddingL,
                    ),
                    child: Row(
                      spacing: ThemeConstants.spaceS,
                      children: [
                        AppSvgIcon(
                          iconAsset,
                          color: context.cs.onSurfaceVariant,
                          size: ThemeConstants.iconL,
                        ),
                        Expanded(
                          child: AppText(
                            label,
                            style: context.tt.bodyMedium?.copyWith(
                              color: context.cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        ?trailing,
                        if (trailing == null && amountText != null)
                          AppText(
                            amountText!,
                            style: context.tt.titleLarge?.copyWith(
                              color: context.cs.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
