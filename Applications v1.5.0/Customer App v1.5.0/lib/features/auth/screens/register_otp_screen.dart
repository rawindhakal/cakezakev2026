import 'dart:async';

import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/commons/widgets/custom_app_bar.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/auth/cubits/auth_cubit.dart';
import 'package:customer/features/auth/cubits/sign_up_cubit.dart';
import 'package:customer/features/auth/cubits/custom_sms_send_phone_otp_cubit.dart';
import 'package:customer/features/auth/cubits/custom_sms_verify_phone_otp_cubit.dart';
import 'package:customer/features/auth/cubits/verify_otp_cubit.dart';
import 'package:customer/features/auth/widgets/auth_otp_fields.dart';
import 'package:customer/features/auth/widgets/auth_resend_section.dart';
import 'package:customer/features/cart/cubit/guest_cart_sync_helper.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/core/constants/theme_constants.dart';

class RegisterOtpArgs {
  final String name;
  final String? email;
  final String? phone;
  final String? countryCode;
  final String? countryId;
  final String? password;
  final String? friendsCode;
  final String? languageId;
  final String phoneAuthType;
  final String authType;
  final String verificationId;

  const RegisterOtpArgs({
    required this.name,
    this.email,
    this.phone,
    this.countryCode,
    this.countryId,
    this.password,
    this.friendsCode,
    this.languageId,
    required this.phoneAuthType,
    required this.authType,
    this.verificationId = '',
  });
}

class RegisterOtpScreen extends StatefulWidget {
  final RegisterOtpArgs args;
  const RegisterOtpScreen({super.key, required this.args});

  @override
  State<RegisterOtpScreen> createState() => _RegisterOtpScreenState();
}

class _RegisterOtpScreenState extends State<RegisterOtpScreen> {
  final _otpController = TextEditingController();
  final _scrollController = ScrollController();

  late String _verificationId;
  Duration _resendTimer = Duration(seconds: AppConfig.otpResendTimerSeconds);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.args.verificationId;
    _startTimer();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _scrollController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(
      () => _resendTimer = Duration(seconds: AppConfig.otpResendTimerSeconds),
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _timer?.cancel();
        return;
      }
      setState(() {
        if (_resendTimer.inSeconds <= 1) {
          _resendTimer = Duration.zero;
          _timer?.cancel();
        } else {
          _resendTimer = Duration(seconds: _resendTimer.inSeconds - 1);
        }
      });
    });
  }

  void _clearOtp() => _otpController.clear();

  String get _otp => _otpController.text;

  void _onVerify() {
    final otp = _otp;
    if (otp.length != 6) {
      AppSnackBar.show(
        context: context,
        message: context.translate(LanguageLabelKeys.enterSixDigitOtp),
        type: SnackBarType.error,
      );
      return;
    }
    final a = widget.args;
    final languageId = a.languageId ?? SettingsHiveBox.instance.languageId;

    if (a.authType == OtpAuthType.email.name) {
      context.read<VerifyOtpCubit>().verifyEmail(email: a.email!, otp: otp);
    } else if (a.authType == OtpAuthType.firebase.name) {
      context.read<VerifyOtpCubit>().verifyPhoneOtpAndSignUp(
        verificationId: _verificationId,
        smsCode: otp,
        name: a.name,
        mobile: a.phone ?? '',
        email: a.email,
        password: a.password,
        phoneAuthType: a.phoneAuthType,
        friendsCode: a.friendsCode,
        languageId: languageId,
        countryCode: a.countryCode,
        countryId: a.countryId,
      );
    } else {
      context.read<CustomSmsVerifyPhoneOtpCubit>().customSmsVerifyPhoneOtp(
        phoneNumber: a.phone ?? '',
        otp: otp,
        countryCode: a.countryCode ?? '',
      );
    }
  }

  Future<void> _onResend() async {
    final a = widget.args;
    final languageId = a.languageId ?? SettingsHiveBox.instance.languageId;
    bool success;

    if (a.authType == OtpAuthType.email.name) {
      final cubit = context.read<SignUpCubit>();
      await cubit.signUpWithEmail(
        name: a.name,
        email: a.email!,
        password: a.password!,
        mobile: a.phone,
        countryCode: a.countryCode,
        countryId: a.countryId,
        friendsCode: a.friendsCode,
        languageId: languageId,
      );
      success = cubit.state is! SignUpError;
    } else if (a.authType == OtpAuthType.firebase.name) {
      final cubit = context.read<SignUpCubit>();
      await cubit.sendPhoneOtpForSignUp(
        phoneNumber: a.phone ?? '',
        countryCode: a.countryCode ?? '',
      );
      success = cubit.state is! SignUpError;
    } else {
      final cubit = context.read<CustomSmsSendPhoneOtpCubit>();
      await cubit.customSmsSendPhoneOtp(
        phoneNumber: '${a.countryCode ?? ''}${a.phone ?? ''}',
      );
      success = cubit.state is CustomSmsSendPhoneOtpLoaded;
    }

    // Only burn the countdown once the resend actually succeeded — on
    // failure the error snackbar already fires via the BlocListener below,
    // and the user can retry immediately instead of waiting out the full
    // interval again.
    if (!mounted || !success) return;
    _clearOtp();
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.args;
    final target = a.authType == OtpAuthType.email.name
        ? (a.email ?? '')
        : '${a.countryCode ?? ''} ${a.phone ?? ''}';

    return MultiBlocListener(
      listeners: [
        BlocListener<VerifyOtpCubit, VerifyOtpState>(
          listener: (context, state) {
            if (state is VerifyOtpLoaded) {
              GuestCartSyncHelper.syncAndNavigate(context);
            } else if (state is VerifyOtpError) {
              AppSnackBar.show(
                context: context,
                message: state.message,
                type: SnackBarType.error,
              );
            }
          },
        ),
        BlocListener<SignUpCubit, SignUpState>(
          listener: (context, state) {
            if (state is SignUpLoaded) {
              if (state.auth?.data?.accessToken?.isNotEmpty == true) {
                GuestCartSyncHelper.syncAndNavigate(context);
              } else {
                AppSnackBar.show(
                  context: context,
                  message: state.message,
                  type: SnackBarType.error,
                );
                AppNavigator.pushReplacementNamed(context, RouteNames.login);
              }
            } else if (state is SignUpPhoneOtpSent) {
              setState(() => _verificationId = state.verificationId);
              AppSnackBar.show(
                context: context,
                message: context.translate(LanguageLabelKeys.resendOtp),
                type: SnackBarType.success,
              );
            } else if (state is SignUpError) {
              AppSnackBar.show(
                context: context,
                message: state.message,
                type: SnackBarType.error,
              );
            }
          },
        ),
        BlocListener<CustomSmsSendPhoneOtpCubit, CustomSmsSendPhoneOtpState>(
          listener: (context, state) {
            if (state is CustomSmsSendPhoneOtpLoaded) {
              AppSnackBar.show(
                context: context,
                message: context.translate(LanguageLabelKeys.resendOtp),
                type: SnackBarType.success,
              );
            } else if (state is CustomSmsSendPhoneOtpError) {
              AppSnackBar.show(
                context: context,
                message: state.message,
                type: SnackBarType.error,
              );
            }
          },
        ),
        BlocListener<
          CustomSmsVerifyPhoneOtpCubit,
          CustomSmsVerifyPhoneOtpState
        >(
          listener: (context, state) {
            if (state is CustomSmsVerifyPhoneOtpLoaded ||
                state is CustomSmsVerifyPhoneOtpUserNotFound) {
              final languageId =
                  a.languageId ?? SettingsHiveBox.instance.languageId;
              context.read<SignUpCubit>().signUp(
                name: a.name,
                mobile: a.phone,
                email: a.email,
                type: AuthType.phone.name,
                phoneAuthType: a.phoneAuthType,
                friendsCode: a.friendsCode,
                languageId: languageId,
                countryCode: a.countryCode,
                countryId: a.countryId,
              );
            } else if (state is CustomSmsVerifyPhoneOtpError) {
              AppSnackBar.show(
                context: context,
                message: state.message,
                type: SnackBarType.error,
              );
            }
          },
        ),
      ],
      child: AppScaffold(
        appBar: CustomAppBar(
          title: context.translate(LanguageLabelKeys.verifyOtp),
          showBackButton: true,
          scrollController: _scrollController,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: ThemeConstants.paddingXXL,
              vertical: ThemeConstants.paddingL,
            ),
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                AppSpacing.h20,
                AppText(
                  '${context.translate(LanguageLabelKeys.codeSentTo)} $target',
                  style: context.tt.bodyMedium?.copyWith(
                    color: context.cs.onSurfaceVariant,
                  ),
                ),
                AppSpacing.h32,
                Center(child: AuthOtpFields(controller: _otpController)),
                AppSpacing.h28,
                AuthResendSection(
                  resendTimer: _resendTimer,
                  onResend: _onResend,
                ),
                AppSpacing.h32,
                _buildVerifyButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerifyButton() {
    return BlocBuilder<VerifyOtpCubit, VerifyOtpState>(
      builder: (context, verifyState) {
        return BlocBuilder<SignUpCubit, SignUpState>(
          builder: (context, signUpState) {
            return BlocBuilder<
              CustomSmsVerifyPhoneOtpCubit,
              CustomSmsVerifyPhoneOtpState
            >(
              builder: (context, customSmsState) {
                final isLoading =
                    verifyState is VerifyOtpLoading ||
                    signUpState is SignUpLoading ||
                    customSmsState is CustomSmsVerifyPhoneOtpLoading;
                return AppButton(
                  label: context.translate(LanguageLabelKeys.verifyOtp),
                  onPressed: isLoading ? null : _onVerify,
                  isLoading: isLoading,
                );
              },
            );
          },
        );
      },
    );
  }
}
