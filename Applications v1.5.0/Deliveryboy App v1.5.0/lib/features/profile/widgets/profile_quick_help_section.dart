import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/local_storage/auth_hive_box.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/routes/route_names.dart';
import 'package:deliveryboy/features/chat/models/chat_message.dart';
import 'package:deliveryboy/features/chat/services/chat_conversation_resolver.dart';
import 'package:deliveryboy/commons/cubit/settings_cubit.dart';
import 'package:deliveryboy/features/profile/screens/policies_screen.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/core/constants/navigation_service.dart';
import 'profile_menu_widgets.dart';

/// Profile section listing help/support and policy links.
class ProfileQuickHelpSection extends StatelessWidget {
  const ProfileQuickHelpSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        ProfileMenuCard(
          title: context.translate(LanguageLabelKeys.helpSupport),
          items: [
            ProfileMenuItemData(
              iconPath: AssetsConstants.supportChatIcon,
              label: context.translate(LanguageLabelKeys.chatWithSupport),
              onTap: () async {
                final conversationId = await resolveAdminConversationId();
                if (!context.mounted) return;
                AppNavigator.pushNamed(
                  context,
                  RouteNames.chat,
                  arguments: ChatScreenArgs(
                    chatType: ChatType.adminChat,
                    recipientName: context.translate(
                      LanguageLabelKeys.chatWithSupport,
                    ),
                    recipientId: int.tryParse(AuthHiveBox.instance.userId) ?? 0,
                    conversationId: conversationId,
                  ),
                );
              },
            ),
            ProfileMenuItemData(
              iconPath: AssetsConstants.rateIcon,
              label: context.translate(LanguageLabelKeys.rateUs),
              onTap: () => launchUrl(
                Uri.parse(context.read<SettingsCubit>().getAppUrl()!),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ],
        ),
        AppSpacing.h12,
        ProfileExpandableMenuSection(
          iconPath: AssetsConstants.helpPolicyIcon,
          label: context.translate(LanguageLabelKeys.helpPolicies),
          title: context.translate(LanguageLabelKeys.helpPolicies),
          children: [
            ProfileMenuItemData(
              iconPath: AssetsConstants.helpPolicyIcon,
              label: context.translate(LanguageLabelKeys.privacyPolicy),
              onTap: () => AppNavigator.pushNamed(
                context,
                RouteNames.policies,
                arguments: PoliciesType.privacyPolicy,
              ),
            ),
            ProfileMenuItemData(
              iconPath: AssetsConstants.helpPolicyIcon,
              label: context.translate(LanguageLabelKeys.termsAndConditions),
              onTap: () => AppNavigator.pushNamed(
                context,
                RouteNames.policies,
                arguments: PoliciesType.termsConditions,
              ),
            ),
          ],
        ),
        AppSpacing.h12,
      ],
    );
  }
}
