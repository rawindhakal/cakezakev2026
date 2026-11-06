import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/features/profile/screens/policies_screen.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';

class AuthTermsBar extends StatelessWidget {
  const AuthTermsBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        ThemeConstants.paddingL,
        ThemeConstants.paddingM,
        ThemeConstants.paddingL,
        ThemeConstants.paddingM + context.bottomSafePadding,
      ),
      child: Text.rich(
        TextSpan(
          style: context.tt.bodySmall?.copyWith(
            color: context.cs.onSurfaceVariant,
            height: 1.5,
          ),
          children: [
            TextSpan(
              text:
                  '${context.translate(LanguageLabelKeys.byAgreeingToContinue)} ',
            ),
            _linkSpan(
              context,
              context.translate(LanguageLabelKeys.termsAndConditions),
              PoliciesType.termsConditions,
            ),
            TextSpan(text: ' ${context.translate(LanguageLabelKeys.and)} '),
            _linkSpan(
              context,
              context.translate(LanguageLabelKeys.privacyPolicy),
              PoliciesType.privacyPolicy,
            ),
          ],
        ),
        textAlign: .center,
      ),
    );
  }

  WidgetSpan _linkSpan(BuildContext context, String label, PoliciesType type) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: GestureDetector(
        onTap: () => AppNavigator.pushNamed(
          context,
          RouteNames.policies,
          arguments: type,
        ),
        child: AppText(
          label,
          style: context.tt.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.cs.onSurface,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}
