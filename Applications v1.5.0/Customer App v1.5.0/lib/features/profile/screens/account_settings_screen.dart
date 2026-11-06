import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/commons/widgets/custom_app_bar.dart';
import 'package:customer/commons/widgets/menu_card.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/features/profile/widgets/profile_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/auth/cubits/auth_cubit.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/core/constants/theme_constants.dart';

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
          ThemeConstants.paddingXXL +
              ThemeConstants.paddingXS +
              context.bottomSafePadding,
        ),
        children: [
          MenuCard(
            title: context.translate(LanguageLabelKeys.general),
            items: [
              MenuItemData(
                iconPath: AssetsConstants.notificationIcon,
                label: context.translate(
                  LanguageLabelKeys.notificationSettings,
                ),
                onTap: () =>
                    AppNavigator.pushNamed(context, RouteNames.notifications),
              ),
              if (AuthHiveBox.instance.isLoggedIn) ...[
                if (AuthHiveBox.instance.userData?.type == AuthType.email.name)
                  MenuItemData(
                    iconPath: AssetsConstants.passwordIcon,
                    label: context.translate(LanguageLabelKeys.changePassword),
                    onTap: () => showChangePasswordSheet(context),
                  ),
                MenuItemData(
                  iconPath: AssetsConstants.deleteIcon,
                  label: context.translate(LanguageLabelKeys.deleteAccount),
                  onTap: () => showDeleteAccountDialog(context),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
