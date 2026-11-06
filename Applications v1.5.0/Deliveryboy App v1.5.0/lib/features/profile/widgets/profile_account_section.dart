import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/routes/route_names.dart';
import 'package:deliveryboy/features/profile/widgets/profile_dialogs.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/core/constants/navigation_service.dart';
import 'profile_menu_widgets.dart';

/// Profile section with account settings and logout actions.
class ProfileAccountSection extends StatelessWidget {
  const ProfileAccountSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        ProfileMenuCard(
          title: context.translate(LanguageLabelKeys.account),
          items: [
            ProfileMenuItemData(
              iconPath: AssetsConstants.settingsIcon,
              label: context.translate(LanguageLabelKeys.settings),
              onTap: () =>
                  AppNavigator.pushNamed(context, RouteNames.accountSettings),
            ),
            ProfileMenuItemData(
              iconPath: AssetsConstants.logoutIcon,
              label: context.translate(LanguageLabelKeys.logout),
              onTap: () => showLogoutDialog(context),
            ),
          ],
        ),
        AppSpacing.h28,
      ],
    );
  }
}
