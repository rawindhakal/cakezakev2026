import 'package:deliveryboy/commons/widgets/app_snack_bar.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/auth/cubit/sign_in_cubit.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../commons/widgets/app_button.dart';
import '../../../commons/widgets/app_text_field.dart';
import '../../../commons/cubit/country_settings_cubit.dart';
import '../../../core/constants/navigation_service.dart';
import '../../../core/routes/route_names.dart';
import '../screens/forgot_password_screen.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../utils/input_validators.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

/// Login form with email/password fields and sign-up navigation link.
class LoginForm extends StatefulWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback onLogin;

  const LoginForm({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.onLogin,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        AppText(
          context.translate(LanguageLabelKeys.email),
          isRequired: true,
          style: context.tt.labelMedium?.copyWith(color: context.cs.onSurface),
        ),
        AppSpacing.h8,
        AppTextField(
          controller: widget.emailController,
          hintText: context.translate(LanguageLabelKeys.enterYourEmail),
          keyboardType: TextInputType.emailAddress,
          validator: (v) => v.validateEmail(context),
        ),
        AppSpacing.h16,
        AppText(
          context.translate(LanguageLabelKeys.password),
          isRequired: true,
          style: context.tt.labelMedium?.copyWith(color: context.cs.onSurface),
        ),
        AppSpacing.h8,
        AppTextField(
          controller: widget.passwordController,
          hintText: context.translate(LanguageLabelKeys.enterPassword),
          obscureText: _obscurePassword,
          suffixIcon: IconButton(
            icon: AppSvgIcon(
              _obscurePassword
                  ? AssetsConstants.passwordHideIcon
                  : AssetsConstants.passwordVisibleIcon,
              color: context.cs.onSurfaceVariant,
              size: ThemeConstants.iconM,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
          validator: (v) => v.validateRequired(
            context,
            context.translate(LanguageLabelKeys.password),
          ),
        ),
        AppSpacing.h6,
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: GestureDetector(
            onTap: () => showForgotPasswordSheet(context),
            child: AppText(
              context.translate(LanguageLabelKeys.forgotPasswordLabel),
              style: context.tt.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.cs.primary,
              ),
            ),
          ),
        ),
        AppSpacing.h20,
        BlocConsumer<SignInCubit, SignInState>(
          listener: (context, state) {
            if (state is SignInLoading) {
              setState(() => _isLoading = true);
            } else {
              setState(() => _isLoading = false);
              if (state is SignInLoaded) {
                context.read<CountrySettingsCubit>().loadCountrySettings(
                  force: true,
                );
                AppNavigator.pushReplacementNamed(context, RouteNames.main);
              } else if (state is SignInError) {
                AppSnackBar.show(
                  context: context,
                  message: state.message,
                  type: SnackBarType.error,
                );
              }
            }
          },
          builder: (context, state) {
            return AppButton(
              label: context.translate(LanguageLabelKeys.login),
              onPressed: widget.onLogin,
              isLoading: _isLoading,
            );
          },
        ),
        AppSpacing.h20,
        Center(
          child: Row(
            mainAxisAlignment: .center,
            children: [
              AppText(
                context.translate(LanguageLabelKeys.dontHaveAccount),
                style: context.tt.labelMedium?.copyWith(
                  color: context.cs.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                ),
              ),
              GestureDetector(
                onTap: () =>
                    AppNavigator.pushNamed(context, RouteNames.register),
                child: AppText(
                  context.translate(LanguageLabelKeys.signUp),
                  style: context.tt.labelMedium?.copyWith(
                    color: context.cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
