import 'dart:io';
import 'package:customer/core/constants/theme_constants.dart';

import '../../../commons/widgets/app_button.dart';

import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';

class AuthSocialButtons extends StatelessWidget {
  final bool isGoogleEnabled;
  final bool isAppleEnabled;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onAppleSignIn;
  final bool isLoading;
  final bool isGoogleLoading;
  final bool isAppleLoading;

  const AuthSocialButtons({
    super.key,
    required this.isGoogleEnabled,
    required this.isAppleEnabled,
    required this.onGoogleSignIn,
    required this.onAppleSignIn,
    this.isLoading = false,
    this.isGoogleLoading = false,
    this.isAppleLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: ThemeConstants.spaceM,
      children: [
        if (isGoogleEnabled)
          _SocialButton(
            onTap: isLoading ? null : onGoogleSignIn,
            isLoading: isGoogleLoading,
            icon: AppSvgIcon(AssetsConstants.googleLogo),
            label: context.translate(LanguageLabelKeys.continueWithGoogle),
          ),
        if (Platform.isIOS && isAppleEnabled)
          _SocialButton(
            onTap: isLoading ? null : onAppleSignIn,
            isLoading: isAppleLoading,
            icon: AppSvgIcon(
              AssetsConstants.appleLogo,
              color: context.cs.onSurface,
            ),
            label: context.translate(LanguageLabelKeys.continueWithApple),
          ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isLoading;
  final Widget icon;
  final String label;

  const _SocialButton({
    required this.onTap,
    this.isLoading = false,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: label,
      onPressed: onTap,
      isLoading: isLoading,
      variant: AppButtonVariant.outline,
      color: context.cs.onSurface,
      backgroundColor: context.cs.surface,
      borderColor: context.cs.outline,
      height: 50,
      prefixIcon: icon,
    );
  }
}
