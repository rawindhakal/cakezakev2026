import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';

class MaintenanceScreen extends StatelessWidget {
  final String? remark;

  const MaintenanceScreen({super.key, this.remark});

  @override
  Widget build(BuildContext context) {
    final message = (remark?.isNotEmpty == true)
        ? remark!
        : context.translate(LanguageLabelKeys.maintenanceSubtitle);

    return PopScope(
      canPop: false,
      child: AppScaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: ThemeConstants.spaceXXXL,
            ),
            child: Column(
              mainAxisAlignment: .center,
              crossAxisAlignment: .center,
              children: [
                AppSvgIcon(
                  AssetsConstants.noMaintenanceFound,
                  size: context.widthFraction(0.48),
                  color: context.cs.primary,
                  useColorMapper: true,
                ),
                AppSpacing.h16,
                // Title
                AppText(
                  context.translate(LanguageLabelKeys.maintenanceTitle),
                  style: context.tt.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w400,
                    color: context.cs.onSurface,
                    fontSize: 22,
                  ),
                  textAlign: .center,
                ),
                AppSpacing.h8,
                // Message
                AppText(
                  message,
                  style: context.tt.bodyMedium?.copyWith(
                    color: context.cs.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                    fontSize: 16,
                  ),
                  textAlign: .center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
