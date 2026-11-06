import 'dart:async';

import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/commons/widgets/api_country_phone_field.dart';
import 'package:customer/commons/cubit/countries_cubit.dart';
import 'package:customer/commons/models/countries_model.dart';
import 'package:customer/features/auth/cubits/auth_cubit.dart';
import 'package:customer/features/auth/cubits/forgot_password_cubit.dart';
import 'package:customer/features/auth/widgets/auth_otp_fields.dart';
import 'package:customer/features/auth/widgets/auth_resend_section.dart';
import 'package:customer/features/auth/widgets/auth_screen_header.dart';
import 'package:customer/features/auth/widgets/forgot_password_input_section.dart';
import 'package:customer/features/auth/widgets/forgot_password_password_section.dart';
import 'package:customer/commons/cubit/settings_cubit.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/show_app_bottom_sheet.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens the bottom sheet for requesting a password reset via OTP (phone or email).
///
/// [cubit] is a test-only seam (mirrors `ApiClient.httpClientAdapter`'s
/// `@visibleForTesting` pattern elsewhere in this codebase): the sheet
/// otherwise always builds its own `ForgotPasswordCubit()`, which — via
/// `AuthRepository()`'s default constructor — touches `FirebaseAuth.instance`
/// eagerly, before any OTP method is ever called. That throws under
/// `flutter test` (no `Firebase.initializeApp()` in the widget/unit test
/// binary), so a widget test has no way to even mount this sheet without
/// supplying an already-constructed cubit here.
void showForgotPasswordSheet(
  BuildContext context, {
  required String type,
  @visibleForTesting ForgotPasswordCubit? cubit,
}) {
  showAppBottomSheet(
    context,
    enableDrag: true,
    builder: (sheetContext) => cubit != null
        ? BlocProvider<ForgotPasswordCubit>.value(
            value: cubit,
            child: _ForgotPasswordSheet(type: type),
          )
        : BlocProvider(
            create: (_) => ForgotPasswordCubit(),
            child: _ForgotPasswordSheet(type: type),
          ),
  );
}

class _ForgotPasswordSheet extends StatefulWidget {
  final String type;
  const _ForgotPasswordSheet({required this.type});

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _otpController = TextEditingController();

  String _countryCode = '';
  CountriesData? _selectedCountry;
  int _phase = 0;
  Duration _resendTimer = Duration.zero;
  Timer? _timer;

  bool get _isPhone => widget.type == AuthType.phone.name;
  bool get _isFirebase {
    final s = context.read<SettingsCubit>().state;
    return s is SettingsLoaded &&
        s.settings.data?.firebaseAuthentication == '1';
  }

  @override
  void initState() {
    super.initState();
    final countriesState = context.read<CountriesCubit>().state;
    if (countriesState is CountriesLoaded) {
      _prefillDefaultCountry(countriesState.countries, useSetState: false);
    }
  }

  void _prefillDefaultCountry(
    List<CountriesData> countries, {
    bool useSetState = true,
  }) {
    if (_selectedCountry != null) return;
    final match = findDefaultCountry(countries);
    if (match == null) return;
    void apply() {
      _selectedCountry = match;
      _countryCode = formatDialCode(match.dialCode);
    }

    useSetState ? setState(apply) : apply();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
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

  String get _otp => _otpController.text;

  void _clearOtp() => _otpController.clear();

  void _onSendOtp() {
    if (!_formKey.currentState!.validate()) return;
    final cubit = context.read<ForgotPasswordCubit>();
    if (_isPhone) {
      cubit.verifyPhoneAndSendOtp(
        mobile: _phoneController.text,
        countryCode: _countryCode,
        isFirebase: _isFirebase,
      );
    } else {
      cubit.sendEmailOtp(email: _emailController.text.trim());
    }
  }

  void _onVerifyOtp() {
    final otp = _otp;
    if (otp.length != 6) {
      AppSnackBar.show(
        context: context,
        message: context.translate(LanguageLabelKeys.enterSixDigitOtp),
        type: SnackBarType.error,
      );
      return;
    }
    if (!_isPhone) {
      if (!_formKey.currentState!.validate()) return;
      context.read<ForgotPasswordCubit>().resetPasswordEmail(
        email: _emailController.text.trim(),
        otp: otp,
        password: _passwordController.text,
        passwordConfirmation: _confirmController.text,
      );
      return;
    }
    if (_isFirebase) {
      context.read<ForgotPasswordCubit>().verifyFirebaseOtp(smsCode: otp);
    } else {
      context.read<ForgotPasswordCubit>().verifyCustomSmsOtp(
        mobile: _phoneController.text,
        otp: otp,
        countryCode: _countryCode,
      );
    }
  }

  void _onResetPassword() {
    if (!_formKey.currentState!.validate()) return;
    context.read<ForgotPasswordCubit>().resetPasswordPhone(
      mobile: _phoneController.text,
      countryCode: _countryCode,
      password: _passwordController.text,
      passwordConfirmation: _confirmController.text,
      otpVerifyMethod: _isFirebase
          ? OtpVerifyMethod.firebase.name
          : OtpVerifyMethod.customSms.name,
    );
  }

  void _onResend() {
    if (_isPhone) {
      context.read<ForgotPasswordCubit>().resendPhoneOtp(
        mobile: _phoneController.text,
        countryCode: _countryCode,
        isFirebase: _isFirebase,
      );
    } else {
      context.read<ForgotPasswordCubit>().sendEmailOtp(
        email: _emailController.text.trim(),
      );
    }
  }

  (String, String) get _headerTexts => switch (_phase) {
    0 => (
      context.translate(LanguageLabelKeys.forgotPassword),
      _isPhone
          ? context.translate(LanguageLabelKeys.enterRegisteredPhoneNumber)
          : context.translate(LanguageLabelKeys.enterRegisteredEmailAddress),
    ),
    1 => (
      context.translate(LanguageLabelKeys.enterOtp),
      _isPhone
          ? '${context.translate(LanguageLabelKeys.codeSentTo)} $_countryCode ${_phoneController.text}'
          : '${context.translate(LanguageLabelKeys.codeSentTo)} ${_emailController.text}',
    ),
    _ => (
      context.translate(LanguageLabelKeys.setNewPassword),
      context.translate(LanguageLabelKeys.enterNewPasswordBelow),
    ),
  };

  @override
  Widget build(BuildContext context) {
    return BlocListener<CountriesCubit, CountriesState>(
      listener: (context, state) {
        if (state is CountriesLoaded) _prefillDefaultCountry(state.countries);
      },
      child: BlocConsumer<ForgotPasswordCubit, ForgotPasswordState>(
        listener: (context, state) {
          if (state is ForgotPasswordOtpSent) {
            if (_phase == 0) setState(() => _phase = 1);
            _clearOtp();
            _startResendTimer();
          } else if (state is ForgotPasswordOtpVerified) {
            setState(() => _phase = 2);
          } else if (state is ForgotPasswordSuccess) {
            AppSnackBar.show(
              context: context,
              message: state.message,
              type: SnackBarType.success,
            );
            AppNavigator.pop(context);
          } else if (state is ForgotPasswordError) {
            AppSnackBar.show(
              context: context,
              message: state.message,
              type: SnackBarType.error,
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is ForgotPasswordLoading;
          final (title, subtitle) = _headerTexts;
          return SingleChildScrollView(
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: ThemeConstants.paddingM,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: .stretch,
                children: [
                  AuthScreenHeader(title: title, subtitle: subtitle),
                  AppSpacing.h24,
                  if (_phase == 0)
                    ForgotPasswordInputSection(
                      isPhone: _isPhone,
                      emailController: _emailController,
                      phoneController: _phoneController,
                      isLoading: isLoading,
                      selectedCountry: _selectedCountry,
                      onCountryCodeChanged: (code) =>
                          setState(() => _countryCode = code),
                      onCountryChanged: (country) =>
                          setState(() => _selectedCountry = country),
                      onSendOtp: _onSendOtp,
                    ),
                  if (_phase == 1) ...[
                    Center(child: AuthOtpFields(controller: _otpController)),
                    AppSpacing.h24,
                    if (!_isPhone)
                      ForgotPasswordPasswordSection(
                        passwordController: _passwordController,
                        confirmPasswordController: _confirmController,
                        isLoading: isLoading,
                        onSubmit: _onVerifyOtp,
                        submitLabel: context.translate(
                          LanguageLabelKeys.resetPassword,
                        ),
                      ),
                    if (_isPhone) ...[
                      AppSpacing.h20,
                      AuthResendSection(
                        resendTimer: _resendTimer,
                        onResend: _onResend,
                      ),
                      AppSpacing.h24,
                      AppButton(
                        label: context.translate(LanguageLabelKeys.verifyOtp),
                        isLoading: isLoading,
                        onPressed: isLoading ? null : _onVerifyOtp,
                      ),
                    ],
                    if (!_isPhone) ...[
                      AppSpacing.h12,
                      AuthResendSection(
                        resendTimer: _resendTimer,
                        onResend: _onResend,
                      ),
                    ],
                  ],
                  if (_phase == 2)
                    ForgotPasswordPasswordSection(
                      passwordController: _passwordController,
                      confirmPasswordController: _confirmController,
                      isLoading: isLoading,
                      onSubmit: _onResetPassword,
                      submitLabel: context.translate(
                        LanguageLabelKeys.resetPassword,
                      ),
                    ),
                  AppSpacing.h16,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
