import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/commons/widgets/custom_app_bar.dart';
import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/core/api/api_parameters.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/features/auth/screens/sign_up_screen.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/auth/cubits/auth_cubit.dart';
import 'package:customer/features/auth/cubits/sign_in_cubit.dart';
import 'package:customer/features/auth/cubits/custom_sms_send_phone_otp_cubit.dart';
import 'package:customer/features/auth/cubits/custom_sms_verify_phone_otp_cubit.dart';
import 'package:customer/features/auth/widgets/auth_otp_fields.dart';
import 'package:customer/features/auth/widgets/auth_resend_section.dart';
import 'package:customer/features/cart/cubit/guest_cart_sync_helper.dart';
import 'package:customer/commons/cubit/settings_cubit.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/commons/widgets/app_text.dart';

/// Typed navigation arguments for [RouteNames.otpVerification].
class OtpVerificationArgs {
  final String phone;
  final String authType;
  final String countryCode;

  const OtpVerificationArgs({
    required this.phone,
    this.authType = 'firebase',
    this.countryCode = '',
  });
}

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String authType;
  final String countryCode;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    this.authType = 'firebase',
    this.countryCode = '',
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  final _scrollController = ScrollController();
  Duration _resendTimer = const Duration(
    seconds: AppConfig.otpResendTimerSeconds,
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
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
      () => _resendTimer = const Duration(
        seconds: AppConfig.otpResendTimerSeconds,
      ),
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

  bool get _isFirebaseOtp {
    final state = context.read<SettingsCubit>().state;
    if (state is SettingsLoaded) {
      return state.settings.data?.firebaseAuthentication == "1";
    }
    return false;
  }

  String get _otp => _otpController.text;

  void _onVerify() {
    final otp = _otp;
    if (otp.length != 6) {
      AppSnackBar.show(
        context: context,
        message: context.translate(LanguageLabelKeys.enterOtp),
        type: SnackBarType.error,
      );
      return;
    }
    if (widget.authType == OtpAuthType.custom.name) {
      context.read<CustomSmsVerifyPhoneOtpCubit>().customSmsVerifyPhoneOtp(
        phoneNumber: widget.phoneNumber,
        otp: otp,
        countryCode: widget.countryCode,
      );
    } else {
      context.read<SignInCubit>().verifyPhoneOtp(
        phoneNumber: widget.phoneNumber,
        type: AuthType.phone.name,
        phoneAuthType: _isFirebaseOtp
            ? ApiParameters.phoneAuthOtp
            : ApiParameters.phoneAuthPassword,
        languageId: SettingsHiveBox.instance.languageId,
        countryCode: widget.countryCode,
      );
    }
  }

  Future<void> _onResend() async {
    bool success;
    if (widget.authType == OtpAuthType.custom.name) {
      final cubit = context.read<CustomSmsSendPhoneOtpCubit>();
      await cubit.customSmsSendPhoneOtp(
        phoneNumber: '${widget.countryCode}${widget.phoneNumber}',
      );
      success = cubit.state is CustomSmsSendPhoneOtpLoaded;
    } else {
      final cubit = context.read<SignInCubit>();
      await cubit.sendPhoneOtp(
        phoneNumber: widget.phoneNumber,
        countryCode: widget.countryCode,
      );
      success = cubit.state is! SignInError;
    }
    // Only burn the countdown once the resend actually succeeded — on
    // failure the error snackbar already fires via the BlocListener below,
    // and the user can retry immediately instead of waiting out the full
    // interval again.
    if (!mounted || !success) return;
    _startTimer();
    _otpController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: CustomAppBar(
        title: context.translate(LanguageLabelKeys.verifyOtp),
        showBackButton: true,
        scrollController: _scrollController,
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<SignInCubit, SignInState>(
            listener: (context, state) {
              if (state is SignInLoaded) {
                GuestCartSyncHelper.syncAndNavigate(context);
              } else if (state is SignInUserNotFound) {
                AppNavigator.pushReplacementNamed(
                  context,
                  RouteNames.register,
                  arguments: RegisterArgs(
                    mode: AuthType.phone,
                    phone: state.phone ?? widget.phoneNumber,
                    otpVerified: true,
                  ),
                );
              } else if (state is SignInError) {
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
              if (state is CustomSmsVerifyPhoneOtpLoaded) {
                GuestCartSyncHelper.syncAndNavigate(context);
              } else if (state is CustomSmsVerifyPhoneOtpUserNotFound) {
                AppNavigator.pushReplacementNamed(
                  context,
                  RouteNames.register,
                  arguments: RegisterArgs(
                    mode: AuthType.phone,
                    phone: state.phone,
                    otpVerified: true,
                  ),
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
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: ThemeConstants.paddingXXL + ThemeConstants.paddingXS,
          ),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              AppSpacing.h48,
              AppText(
                '${context.translate(LanguageLabelKeys.codeSentTo)} ${widget.countryCode} ${widget.phoneNumber}',
                style: context.tt.bodyMedium?.copyWith(
                  color: context.cs.onSurfaceVariant,
                ),
              ),
              AppSpacing.h32,
              Center(child: AuthOtpFields(controller: _otpController)),
              AppSpacing.h28,
              AuthResendSection(resendTimer: _resendTimer, onResend: _onResend),
              AppSpacing.h32,
              _buildVerifyButton(),
              AppSpacing.h28,
              Center(
                child: TextButton(
                  onPressed: () => AppNavigator.pop(context),
                  child: AppText(
                    context.translate(LanguageLabelKeys.changePhoneNumber),
                    style: context.tt.bodyMedium?.copyWith(
                      color: context.cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerifyButton() {
    return BlocBuilder<SignInCubit, SignInState>(
      builder: (context, signInState) {
        return BlocBuilder<
          CustomSmsVerifyPhoneOtpCubit,
          CustomSmsVerifyPhoneOtpState
        >(
          builder: (context, customSmsState) {
            final isLoading =
                signInState is SignInLoading ||
                customSmsState is CustomSmsVerifyPhoneOtpLoading;
            return AppButton(
              label: context.translate(LanguageLabelKeys.verifyOtp),
              onPressed: _onVerify,
              isLoading: isLoading,
              height: 54,
            );
          },
        );
      },
    );
  }
}
