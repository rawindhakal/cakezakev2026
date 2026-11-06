import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class BackToTopButton extends StatelessWidget {
  final ValueListenable<bool> visibleListenable;
  final VoidCallback onTap;

  const BackToTopButton({
    super.key,
    required this.visibleListenable,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: visibleListenable,
      builder: (context, visible, _) {
        return AnimatedSlide(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          offset: visible ? Offset.zero : const Offset(0, -1),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: visible ? 1 : 0,
            child: IgnorePointer(
              ignoring: !visible,
              child: Material(
                color: context.cs.inverseSurface.withValues(alpha: 0.85),
                shape: const StadiumBorder(),
                elevation: 4,
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ThemeConstants.paddingM,
                      vertical: ThemeConstants.paddingS,
                    ),
                    child: Row(
                      mainAxisSize: .min,
                      children: [
                        AppSvgIcon(
                          AssetsConstants.arrowUpAndroidIcon,
                          color: context.cs.onInverseSurface,
                          size: ThemeConstants.iconS,
                        ),
                        const SizedBox(width: 6),
                        AppText(
                          context.translate(LanguageLabelKeys.backToTop),
                          style: context.tt.labelMedium?.copyWith(
                            color: context.cs.onInverseSurface,
                            fontWeight: FontWeight.w600,
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
