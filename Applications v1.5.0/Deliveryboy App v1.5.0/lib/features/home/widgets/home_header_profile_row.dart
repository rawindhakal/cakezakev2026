import 'package:deliveryboy/commons/widgets/app_network_image.dart';
import 'package:deliveryboy/core/constants/app_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import '../../../core/theme/app_radius.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

/// Profile avatar, greeting, and online/offline toggle row in the home header.
class HomeHeaderProfileRow extends StatelessWidget {
  final String name;
  final String email;
  final String profileUrl;
  final bool isOnline;
  final VoidCallback onToggle;

  const HomeHeaderProfileRow({
    super.key,
    required this.name,
    required this.email,
    required this.profileUrl,
    required this.isOnline,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: context.screenWidth * 0.123,
          height: context.screenWidth * 0.123,
          decoration: AppDecorations.circle(
            color: context.cs.primaryContainer,
            border: Border.all(
              color: context.cs.primary.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: profileUrl.isNotEmpty
              ? ClipOval(
                  child: AppNetworkImage(
                    url: profileUrl,
                    width: context.screenWidth * 0.123,
                    height: context.screenWidth * 0.123,
                    fit: .cover,
                  ),
                )
              : Center(
                  child: AppText(
                    name.isNotEmpty ? name[0].toUpperCase() : 'D',
                    style: context.tt.titleLarge?.copyWith(
                      color: context.cs.primary,
                    ),
                  ),
                ),
        ),
        AppSpacing.w12,
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            spacing: ThemeConstants.spaceXXS,
            children: [
              AppText(
                '${context.translate(LanguageLabelKeys.helloUser)}, $name ${AppConstants.heySymbol}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.tt.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: context.cs.onSurface,
                ),
              ),
              AppText(
                email,
                overflow: TextOverflow.ellipsis,
                style: context.tt.bodySmall?.copyWith(
                  color: context.cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Builder(
          builder: (context) {
            final knobSize = context.screenWidth * 0.064;
            return GestureDetector(
              onTap: onToggle,
              child: IntrinsicWidth(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  constraints: const BoxConstraints(minWidth: 92),
                  height: context.screenHeight * 0.039,
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: ThemeConstants.paddingXS,
                  ),
                  decoration: AppDecorations.card(
                    color: isOnline
                        ? context.cs.primary
                        : context.cs.surfaceContainerHighest,
                    borderRadius: AppRadius.r16,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 250),
                        alignment: isOnline
                            ? AlignmentDirectional.centerStart
                            : AlignmentDirectional.centerEnd,
                        child: Padding(
                          padding: EdgeInsetsDirectional.only(
                            start: isOnline ? 10 : knobSize + 6,
                            end: isOnline ? knobSize + 6 : 10,
                          ),
                          child: AppText(
                            isOnline
                                ? context.translate(LanguageLabelKeys.online)
                                : context.translate(LanguageLabelKeys.offline),
                            maxLines: 1,
                            softWrap: false,
                            style: context.tt.labelMedium?.copyWith(
                              color: isOnline
                                  ? context.cs.onPrimary
                                  : context.cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 250),
                        alignment: isOnline
                            ? AlignmentDirectional.centerEnd
                            : AlignmentDirectional.centerStart,
                        child: Container(
                          width: knobSize,
                          height: knobSize,
                          decoration: AppDecorations.circle(
                            color: context.cs.surface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
