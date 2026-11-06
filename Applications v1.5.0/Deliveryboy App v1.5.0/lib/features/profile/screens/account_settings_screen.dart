import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:deliveryboy/commons/widgets/app_scaffold.dart';
import 'package:deliveryboy/commons/widgets/custom_app_bar.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/routes/route_names.dart';
import 'package:deliveryboy/features/profile/widgets/profile_dialogs.dart';
import 'package:deliveryboy/features/profile/widgets/profile_menu_widgets.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/core/constants/navigation_service.dart';

/// Screen showing the account section (settings, logout) of the profile.
class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      applyBottomInset: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(
        title: context.translate(LanguageLabelKeys.settings),
        scrollController: _scrollController,
      ),
      body: ListView(
        controller: _scrollController,
        padding: EdgeInsetsDirectional.fromSTEB(
          ThemeConstants.paddingL,
          ThemeConstants.paddingL,
          ThemeConstants.paddingL,
          28 + context.bottomSafePadding,
        ),
        children: [
          ProfileMenuCard(
            title: context.translate(LanguageLabelKeys.general),
            items: [
              ProfileMenuItemData(
                iconPath: AssetsConstants.notificationIcon,
                label: context.translate(LanguageLabelKeys.notifications),
                onTap: () =>
                    AppNavigator.pushNamed(context, RouteNames.notifications),
              ),
              ProfileMenuItemData(
                iconPath: AssetsConstants.passwordIcon,
                label: context.translate(LanguageLabelKeys.changePassword),
                onTap: () => showChangePasswordSheet(context),
              ),
              ProfileMenuItemData(
                iconPath: AssetsConstants.deleteIcon,
                label: context.translate(LanguageLabelKeys.deleteAccount),
                onTap: () => showDeleteAccountDialog(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
