import 'dart:io';
import 'package:deliveryboy/commons/cubit/connectivity_cubit.dart';
import 'package:deliveryboy/commons/widgets/app_no_internet_widget.dart';
import 'package:deliveryboy/commons/widgets/app_scaffold.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/api/api_parameters.dart';
import 'package:deliveryboy/core/configs/app_config.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/features/auth/cubit/sign_in_cubit.dart';
import 'package:deliveryboy/features/auth/widgets/login_form.dart';
import 'package:deliveryboy/core/local_storage/auth_hive_box.dart';
import 'package:deliveryboy/core/local_storage/settings_hive_box.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';

/// Screen for delivery boy email/password login.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: AppConfig.defultEmail);
  final _passwordController = TextEditingController(
    text: AppConfig.defultPassword,
  );

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLogin() async {
    String fcmToken = AuthHiveBox.instance.fcmToken;
    if (fcmToken.isEmpty) {
      final token = await FirebaseMessaging.instance.getToken();
      fcmToken = token ?? '';
      if (fcmToken.isNotEmpty) {
        await AuthHiveBox.instance.setFcmToken(fcmToken);
      }
    }
    if (!mounted) return;
    final platform = Platform.isAndroid
        ? ApiParameters.android
        : ApiParameters.ios;
    final languageId = SettingsHiveBox.instance.languageId;
    context.read<SignInCubit>().login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      fcmToken: fcmToken,
      platform: platform,
      languageId: languageId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectivityCubit, ConnectivityState>(
      builder: (context, connectivityState) {
        if (connectivityState is ConnectivityDisconnected) {
          // Login can't work offline, and this is the root of the unauthed
          // stack, so there is no back button to preserve.
          return const AppNoInternetFullScreen();
        }
        return AppScaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Column(
            children: [
              Container(
                width: double.infinity,
                decoration: AppDecorations.card(
                  color: context.cs.primary.withValues(alpha: 0.1),
                ),
                child: AppSvgIcon(
                  AssetsConstants.loginIcon,
                  size: context.screenHeight / 2.5,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: ThemeConstants.paddingXXL,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: .start,
                      children: [
                        AppSpacing.h28,
                        LoginForm(
                          emailController: _emailController,
                          passwordController: _passwordController,
                          onLogin: _onLogin,
                        ),
                        AppSpacing.h24,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
