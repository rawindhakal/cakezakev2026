import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/features/chat/models/chat_message.dart';
import 'package:customer/features/chat/services/chat_conversation_resolver.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/core/constants/theme_constants.dart';

/// App-bar pill button — opens an admin chat scoped to [orderId] via
/// `chat/start_order_admin`, for order-detail screens (quick + ecommerce).
class OrderHelpButton extends StatefulWidget {
  final String orderId;

  const OrderHelpButton({super.key, required this.orderId});

  @override
  State<OrderHelpButton> createState() => _OrderHelpButtonState();
}

class _OrderHelpButtonState extends State<OrderHelpButton> {
  bool _isLoading = false;

  Future<void> _openChat() async {
    if (_isLoading || !AuthHiveBox.instance.isLoggedIn) return;
    setState(() => _isLoading = true);
    final conversationId = await resolveOrderAdminConversationId(
      widget.orderId,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    AppNavigator.pushNamed(
      context,
      RouteNames.chat,
      arguments: ChatScreenArgs(
        chatType: ChatType.adminChat,
        recipientName: context.translate(LanguageLabelKeys.chatWithSupport),
        recipientId: AuthHiveBox.instance.userId,
        orderId: widget.orderId,
        conversationId: conversationId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthHiveBox.instance.isLoggedIn) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsetsDirectional.only(end: ThemeConstants.paddingM),
      child: AppButton(
        label: context.translate(LanguageLabelKeys.help),
        onPressed: _openChat,
        isLoading: _isLoading,
        variant: AppButtonVariant.outline,
        color: context.cs.onSurfaceVariant,
        fullWidth: false,
        height: 32,
        fontSize: 13,
        borderRadius: AppRadius.r20,
        borderColor: context.cs.onSurfaceVariant,
        contentPadding: const EdgeInsetsDirectional.symmetric(
          horizontal: ThemeConstants.paddingM,
          vertical: ThemeConstants.paddingXS,
        ),
        prefixIcon: AppSvgIcon(
          AssetsConstants.supportChatIcon,
          size: ThemeConstants.iconXS,
          color: context.cs.onSurfaceVariant,
        ),
      ),
    );
  }
}
