import 'package:deliveryboy/commons/widgets/app_network_image.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/local_storage/auth_hive_box.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/routes/route_names.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/core/constants/navigation_service.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

/// Displays the rider's avatar, name/email (or login prompt) at profile top.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box>(
      valueListenable: AuthHiveBox.instance.listenable,
      builder: (context, box, child) {
        final name = AuthHiveBox.instance.userName;
        final email = AuthHiveBox.instance.userEmail;
        final imageUrl = AuthHiveBox.instance.userProfile;
        final isLoggedIn = AuthHiveBox.instance.isLoggedIn;

        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(ThemeConstants.paddingL, ThemeConstants.paddingL, ThemeConstants.paddingL, ThemeConstants.paddingS),
          child: Container(
            decoration: AppDecorations.shadowedCard(
              color: Theme.of(context).cardColor,
              shadowColor: context.cs.shadow,
            ),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: ThemeConstants.paddingL,
              vertical: ThemeConstants.paddingL,
            ),
            child: Row(
              children: [
                Container(
                  width: context.screenWidth * 0.16,
                  height: context.screenWidth * 0.16,
                  decoration: AppDecorations.circle(
                    color: context.cs.surfaceContainerHigh,
                  ),
                  clipBehavior: .antiAlias,
                  child: isLoggedIn && imageUrl.isNotEmpty
                      ? AppNetworkImage(
                          url: imageUrl,
                          placeholder: AppSvgIcon(
                            AssetsConstants.userIcon,
                            size: ThemeConstants.iconXL,
                            color: context.cs.onSurfaceVariant,
                            fit: BoxFit.scaleDown,
                          ),
                          errorWidget: AppSvgIcon(
                            AssetsConstants.userIcon,
                            size: ThemeConstants.iconXL,
                            color: context.cs.onSurfaceVariant,
                            fit: BoxFit.scaleDown,
                          ),
                        )
                      : AppSvgIcon(
                          AssetsConstants.userIcon,
                          size: ThemeConstants.iconL,
                          color: context.cs.onSurfaceVariant,
                          fit: BoxFit.scaleDown,
                        ),
                ),
                AppSpacing.w14,
                Expanded(
                  child: isLoggedIn
                      ? Column(
                          crossAxisAlignment: .start,
                          children: [
                            AppText(
                              name,
                              style: context.tt.titleLarge?.copyWith(
                                fontSize: 17,
                                color: context.cs.onSurface,
                              ),
                              maxLines: 1,
                              overflow: .ellipsis,
                            ),
                            AppSpacing.h3,
                            AppText(
                              email,
                              style: context.tt.headlineLarge?.copyWith(
                                color: context.cs.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: .ellipsis,
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: .start,
                          children: [
                            AppText(
                              context.translate(LanguageLabelKeys.guest),
                              style: context.tt.titleLarge?.copyWith(
                                fontSize: 17,
                                color: context.cs.onSurface,
                              ),
                            ),
                            AppSpacing.h3,
                            GestureDetector(
                              onTap: () => AppNavigator.pushNamed(
                                context,
                                RouteNames.login,
                              ),
                              child: AppText(
                                context.translate(
                                  LanguageLabelKeys.loginRegister,
                                ),
                                style: context.tt.labelMedium?.copyWith(
                                  color: context.cs.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
                if (isLoggedIn) ...[
                  AppSpacing.w8,
                  GestureDetector(
                    onTap: () =>
                        AppNavigator.pushNamed(context, RouteNames.editProfile),
                    child: Container(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: ThemeConstants.paddingM,
                        vertical: 6,
                      ),
                      decoration: AppDecorations.card(
                        color: context.cs.surfaceContainerHigh,
                        borderRadius: AppRadius.r8,
                      ),
                      child: Row(
                        mainAxisSize: .min,
                        spacing: ThemeConstants.spaceXS,
                        children: [
                          AppSvgIcon(
                            AssetsConstants.editIcon,
                            size: ThemeConstants.iconM,
                            color: context.cs.onSurface,
                          ),
                          AppSpacing.w4,
                          AppText(
                            context.translate(LanguageLabelKeys.edit),
                            style: context.tt.labelSmall?.copyWith(
                              color: context.cs.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
