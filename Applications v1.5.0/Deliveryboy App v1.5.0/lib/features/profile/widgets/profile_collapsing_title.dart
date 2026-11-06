import 'package:deliveryboy/commons/widgets/app_network_image.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/navigation_service.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/local_storage/auth_hive_box.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/routes/route_names.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Scroll distance (px) over which the header card collapses into the app bar.
const double _kHeaderCollapseStart = 30;
const double _kHeaderCollapseEnd = 110;

/// 0 → 1 collapse progress of the profile header for [controller].
double profileCollapseProgress(ScrollController controller) {
  if (!controller.hasClients) return 0;
  return ((controller.offset - _kHeaderCollapseStart) /
          (_kHeaderCollapseEnd - _kHeaderCollapseStart))
      .clamp(0.0, 1.0);
}

/// App bar title: "My Profile" fades out, then avatar, name and email slide
/// in one after another as the scroll progress goes 0 → 1 (the body header
/// card fades out over the same range).
class ProfileCollapsingTitle extends StatelessWidget {
  final ScrollController controller;
  final String title;

  const ProfileCollapsingTitle({
    super.key,
    required this.controller,
    required this.title,
  });

  static double _step(double p, double begin, double end) =>
      Curves.easeOutCubic.transform(((p - begin) / (end - begin)).clamp(0, 1));

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final p = profileCollapseProgress(controller);
        final titleT = 1 - _step(p, 0, 0.35);
        final avatarT = _step(p, 0.25, 0.65);
        final nameT = _step(p, 0.4, 0.8);
        final emailT = _step(p, 0.55, 1);

        return ValueListenableBuilder<Box>(
          valueListenable: AuthHiveBox.instance.listenable,
          builder: (context, box, _) {
            final isLoggedIn = AuthHiveBox.instance.isLoggedIn;
            final name = isLoggedIn
                ? AuthHiveBox.instance.userName
                : context.translate(LanguageLabelKeys.guest);
            final email = AuthHiveBox.instance.userEmail;
            final imageUrl = isLoggedIn ? AuthHiveBox.instance.userProfile : '';
            final userIcon = AppSvgIcon(
              AssetsConstants.userIcon,
              size: 18,
              color: context.cs.onSurfaceVariant,
              fit: BoxFit.scaleDown,
            );

            // CustomAppBar already applies titleSpacing (16), matching the
            // body cards' side padding, so no extra padding here.
            return Padding(
              padding: EdgeInsets.zero,
              child: Stack(
                alignment: AlignmentDirectional.centerStart,
                children: [
                  if (titleT > 0)
                    Opacity(
                      opacity: titleT,
                      child: Transform.translate(
                        offset: Offset(0, -12 * (1 - titleT)),
                        child: AppText(
                          title,
                          style: context.tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.cs.onSurface,
                          ),
                        ),
                      ),
                    ),
                  if (p > 0)
                    Row(
                      children: [
                        Opacity(
                          opacity: avatarT,
                          child: Transform.scale(
                            scale: 0.6 + 0.4 * avatarT,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: AppDecorations.circle(
                                color: context.cs.surfaceContainerHigh,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: imageUrl.isNotEmpty
                                  ? AppNetworkImage(
                                      url: imageUrl,
                                      placeholder: userIcon,
                                      errorWidget: userIcon,
                                    )
                                  : userIcon,
                            ),
                          ),
                        ),
                        AppSpacing.w10,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Opacity(
                                opacity: nameT,
                                child: Transform.translate(
                                  offset: Offset(0, 10 * (1 - nameT)),
                                  child: AppText(
                                    name,
                                    style: context.tt.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: context.cs.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              if (isLoggedIn && email.isNotEmpty)
                                Opacity(
                                  opacity: emailT,
                                  child: Transform.translate(
                                    offset: Offset(0, 10 * (1 - emailT)),
                                    child: AppText(
                                      email,
                                      style: context.tt.bodySmall?.copyWith(
                                        fontSize: 11,
                                        color: context.cs.onSurfaceVariant,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (isLoggedIn) ...[
                          AppSpacing.w8,
                          IgnorePointer(
                            ignoring: emailT < 0.5,
                            child: Opacity(
                              opacity: emailT,
                              child: Transform.scale(
                                scale: 0.6 + 0.4 * emailT,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => AppNavigator.pushNamed(
                                    context,
                                    RouteNames.editProfile,
                                  ),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: AppDecorations.card(
                                      color: context.cs.surfaceContainerHigh,
                                      borderRadius: AppRadius.r8,
                                    ),
                                    alignment: Alignment.center,
                                    child: AppSvgIcon(
                                      AssetsConstants.editIcon,
                                      size: ThemeConstants.iconS,
                                      color: context.cs.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
