import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

class ChatEmojiPicker extends StatelessWidget {
  final TextEditingController controller;
  const ChatEmojiPicker({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: context.screenHeight * 0.345,
      child: EmojiPicker(
        textEditingController: controller,
        config: Config(
          emojiViewConfig: EmojiViewConfig(
            backgroundColor: context.cs.surfaceContainerLow,
            noRecents: AppText(
              context.translate(LanguageLabelKeys.noRecentEmojis),
              style: context.tt.bodyMedium?.copyWith(
                color: context.cs.onSurfaceVariant,
              ),
            ),
          ),
          categoryViewConfig: CategoryViewConfig(
            backgroundColor: context.cs.surfaceContainerLow,
            iconColorSelected: context.cs.primary,
            iconColor: context.cs.onSurfaceVariant,
            indicatorColor: context.cs.primary,
          ),
          bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
          searchViewConfig: SearchViewConfig(
            backgroundColor: context.cs.surfaceContainerLow,
            buttonIconColor: context.cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
