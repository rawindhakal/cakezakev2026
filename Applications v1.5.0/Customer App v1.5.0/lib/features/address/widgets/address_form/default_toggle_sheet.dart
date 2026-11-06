import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/commons/widgets/app_switch.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';

/// Flat "set as default" row — plain text + switch, no card.
class DefaultToggleSheet extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const DefaultToggleSheet({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            spacing: ThemeConstants.spaceXXS,
            children: [
              AppText(
                context.translate(LanguageLabelKeys.setAsDefaultAddress),
                style: context.tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.cs.onSurface,
                ),
              ),
              AppText(
                value
                    ? context.translate(LanguageLabelKeys.defaultAddressHintOn)
                    : context.translate(
                        LanguageLabelKeys.defaultAddressHintOff,
                      ),
                style: context.tt.labelSmall?.copyWith(
                  color: context.cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        AppSwitch(value: value, onChanged: onChanged),
      ],
    );
  }
}
