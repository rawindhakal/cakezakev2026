import 'package:customer/commons/models/app_settings_model.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/auth/cubits/auth_cubit.dart';
import 'package:customer/features/auth/cubits/sign_up_cubit.dart';
import 'package:customer/features/auth/cubits/custom_sms_send_phone_otp_cubit.dart';
import 'package:customer/features/auth/screens/register_otp_screen.dart';
import 'package:customer/commons/widgets/custom_app_bar.dart';
import 'package:customer/features/auth/widgets/sign_up_form.dart';
import 'package:customer/commons/widgets/api_country_phone_field.dart';
import 'package:customer/commons/cubit/countries_cubit.dart';
import 'package:customer/commons/models/countries_model.dart';
import 'package:customer/features/cart/cubit/guest_cart_sync_helper.dart';
import 'package:customer/commons/cubit/settings_cubit.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';

/// Typed navigation arguments for [RouteNames.register].
class RegisterArgs {
  final AuthType mode;
  final String? email;
  final String? name;
  final String? phone;
  final bool otpVerified;

  const RegisterArgs({
    required this.mode,
    this.email,
    this.name,
    this.phone,
    this.otpVerified = false,
  });
}

class SignUpScreen extends StatefulWidget {
  final AuthType mode;
  final String? prefilledEmail;
  final String? prefilledName;
  final String? prefilledPhone;
  final bool otpVerified;

  const SignUpScreen({
    super.key,
    required this.mode,
    this.prefilledEmail,
    this.prefilledName,
    this.prefilledPhone,
    this.otpVerified = false,
  });

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _referralController = TextEditingController();
  final _scrollController = ScrollController();

  String _fullPhoneNumber = '';
  String _countryCode = '';
  CountriesData? _selectedCountry;
  String? _phoneError;
  AppSettingsData? _settings;

  bool get _isFirebaseOtp => _settings?.firebaseAuthentication == "1";
  bool get _isPhonePassword => _settings?.phoneAuthPassword == "1";
  bool get _isCustomOtp => _settings?.customSmsGatewayOtpBased == "1";
  bool get _showPassword =>
      widget.mode == AuthType.email ||
      (widget.mode == AuthType.phone && _isPhonePassword);

  String get _registrationType => switch (widget.mode) {
    AuthType.email => AuthType.email.name,
    AuthType.phone || AuthType.phoneWithPassword => AuthType.phone.name,
    AuthType.google => AuthType.google.name,
    AuthType.apple => AuthType.apple.name,
  };

  String get _registrationPhoneAuthType => switch (widget.mode) {
    AuthType.email ||
    AuthType.phoneWithPassword => PhoneAuthType.password.apiValue,
    AuthType.phone => PhoneAuthType.otp.apiValue,
    AuthType.google || AuthType.apple => PhoneAuthType.social.apiValue,
  };

  @override
  void initState() {
    super.initState();
    if (widget.prefilledName != null) {
      _nameController.text = widget.prefilledName!;
    }
    if (widget.prefilledEmail != null) {
      _emailController.text = widget.prefilledEmail!;
    }
    if (widget.prefilledPhone != null) {
      _phoneController.text = widget.prefilledPhone!;
      _fullPhoneNumber = widget.prefilledPhone!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String? get _countryId => _selectedCountry?.id?.toString();

  void _prefillDefaultCountry(List<CountriesData> countries) {
    if (_selectedCountry != null) return;
    final match = findDefaultCountry(countries);
    if (match != null) {
      setState(() {
        _selectedCountry = match;
        _countryCode = formatDialCode(match.dialCode);
      });
    }
  }

  void _onSignUp() {
    if (!_formKey.currentState!.validate()) return;
    final languageId = SettingsHiveBox.instance.languageId;

    if (widget.mode == AuthType.email) {
      context.read<SignUpCubit>().signUpWithEmail(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        mobile: _fullPhoneNumber.isEmpty ? null : _fullPhoneNumber,
        countryCode: _fullPhoneNumber.isEmpty ? null : _countryCode,
        friendsCode: _referralController.text.trim().isEmpty
            ? null
            : _referralController.text.trim(),
        languageId: languageId,
        countryId: _countryId,
      );
    } else if (widget.mode == AuthType.phone) {
      if (_fullPhoneNumber.isEmpty) {
        setState(
          () => _phoneError = context.translate(
            LanguageLabelKeys.pleaseEnterPhoneNumber,
          ),
        );
        return;
      }
      setState(() => _phoneError = null);
      if (widget.otpVerified) {
        context.read<SignUpCubit>().signUp(
          name: _nameController.text.trim(),
          mobile: _fullPhoneNumber,
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          type: AuthType.phone.name,
          phoneAuthType: (_isFirebaseOtp || _isCustomOtp)
              ? PhoneAuthType.otp.apiValue
              : PhoneAuthType.password.apiValue,
          friendsCode: _referralController.text.trim().isEmpty
              ? null
              : _referralController.text.trim(),
          languageId: languageId,
          countryCode: _countryCode,
          countryId: _countryId,
        );
      } else if (_isPhonePassword || _isFirebaseOtp) {
        context.read<SignUpCubit>().sendPhoneOtpForSignUp(
          phoneNumber: _fullPhoneNumber,
          countryCode: _countryCode,
        );
      } else if (_isCustomOtp) {
        context.read<CustomSmsSendPhoneOtpCubit>().customSmsSendPhoneOtp(
          phoneNumber: '$_countryCode$_fullPhoneNumber',
        );
      }
    } else {
      context.read<SignUpCubit>().signUp(
        name: _nameController.text.trim(),
        mobile: _fullPhoneNumber.isEmpty ? null : _fullPhoneNumber,
        countryCode: _countryCode,
        password: _showPassword ? _passwordController.text : null,
        type: _registrationType,
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        friendsCode: _referralController.text.trim().isEmpty
            ? null
            : _referralController.text.trim(),
        phoneAuthType: _registrationPhoneAuthType,
        languageId: languageId,
        countryId: _countryId,
      );
    }
  }

  void _navigateToRegisterOtp({
    required String authType,
    String verificationId = '',
  }) {
    final languageId = SettingsHiveBox.instance.languageId;
    AppNavigator.pushNamed(
      context,
      RouteNames.registerOtp,
      arguments: RegisterOtpArgs(
        name: _nameController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        phone: _fullPhoneNumber.isEmpty ? null : _fullPhoneNumber,
        countryCode: _countryCode,
        countryId: _countryId,
        password: _passwordController.text.isEmpty
            ? null
            : _passwordController.text,
        friendsCode: _referralController.text.trim().isEmpty
            ? null
            : _referralController.text.trim(),
        languageId: languageId,
        phoneAuthType: (_isFirebaseOtp || _isCustomOtp)
            ? PhoneAuthType.otp.apiValue
            : PhoneAuthType.password.apiValue,
        authType: authType,
        verificationId: verificationId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settingsState) {
        if (settingsState is SettingsLoaded) {
          _settings = settingsState.settings.data;
          if (_selectedCountry == null) {
            final countriesState = context.read<CountriesCubit>().state;
            if (countriesState is CountriesLoaded) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _prefillDefaultCountry(countriesState.countries),
              );
            }
          }
        }
        return AppScaffold(
          applyBottomInset: false,
          appBar: CustomAppBar(
            title: context.translate(LanguageLabelKeys.createAccount),
            scrollController: _scrollController,
            subtitle:
                (widget.mode == AuthType.google ||
                    widget.mode == AuthType.apple)
                ? context.translate(LanguageLabelKeys.completeProfileToContinue)
                : context.translate(LanguageLabelKeys.fillDetailsToGetStarted),
          ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: ThemeConstants.paddingXXL,
              vertical: ThemeConstants.paddingM,
            ),
            child: SafeArea(top: false, child: _buildSignUpButton()),
          ),
          body: MultiBlocListener(
            listeners: [
              BlocListener<SignUpCubit, SignUpState>(
                listener: (context, state) {
                  if (state is SignUpLoaded) {
                    if (state.auth?.data?.accessToken?.isNotEmpty == true) {
                      GuestCartSyncHelper.syncAndNavigate(context);
                    } else {
                      AppSnackBar.show(
                        context: context,
                        message: state.message,
                        type: SnackBarType.info,
                      );
                      AppNavigator.pushReplacementNamed(
                        context,
                        RouteNames.login,
                      );
                    }
                  } else if (state is SignUpEmailOtpRequired) {
                    _navigateToRegisterOtp(authType: OtpAuthType.email.name);
                  } else if (state is SignUpPhoneOtpSent) {
                    _navigateToRegisterOtp(
                      authType: OtpAuthType.firebase.name,
                      verificationId: state.verificationId,
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
              BlocListener<
                CustomSmsSendPhoneOtpCubit,
                CustomSmsSendPhoneOtpState
              >(
                listener: (context, state) {
                  if (state is CustomSmsSendPhoneOtpLoaded) {
                    _navigateToRegisterOtp(authType: OtpAuthType.custom.name);
                  } else if (state is CustomSmsSendPhoneOtpError) {
                    AppSnackBar.show(
                      context: context,
                      message: state.message,
                      type: SnackBarType.error,
                    );
                  }
                },
              ),
              BlocListener<CountriesCubit, CountriesState>(
                listener: (context, state) {
                  if (state is CountriesLoaded) {
                    _prefillDefaultCountry(state.countries);
                  }
                },
              ),
            ],
            child: SafeArea(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: ThemeConstants.paddingXXL,
                ),
                child: Column(
                  crossAxisAlignment: .stretch,
                  children: [
                    AppSpacing.h24,
                    SignUpForm(
                      formKey: _formKey,
                      nameController: _nameController,
                      emailController: _emailController,
                      phoneController: _phoneController,
                      passwordController: _passwordController,
                      confirmPasswordController: _confirmPasswordController,
                      referralController: _referralController,
                      mode: widget.mode,
                      showEmail: true,
                      showPhone: true,
                      showPassword: _showPassword,
                      phoneReadOnly: widget.prefilledPhone != null,
                      phoneError: _phoneError,
                      onPhoneChanged: (number, code) => setState(() {
                        _fullPhoneNumber = number;
                        _countryCode = code;
                        if (_phoneError != null && number.isNotEmpty) {
                          _phoneError = null;
                        }
                      }),
                      selectedCountry: _selectedCountry,
                      onCountryChanged: (country) => setState(() {
                        _selectedCountry = country;
                        _countryCode = formatDialCode(country.dialCode);
                      }),
                    ),
                    AppSpacing.h28,
                    _buildLoginRow(),
                    AppSpacing.h24,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSignUpButton() {
    return BlocBuilder<SignUpCubit, SignUpState>(
      builder: (context, signUpState) {
        return BlocBuilder<
          CustomSmsSendPhoneOtpCubit,
          CustomSmsSendPhoneOtpState
        >(
          builder: (context, customSmsState) {
            final isLoading =
                signUpState is SignUpLoading ||
                customSmsState is CustomSmsSendPhoneOtpLoading;
            return AppButton(
              label: (widget.mode == AuthType.phone && !widget.otpVerified)
                  ? context.translate(LanguageLabelKeys.sendOtp)
                  : context.translate(LanguageLabelKeys.createAccount),
              onPressed: isLoading ? null : _onSignUp,
              isLoading: isLoading,
            );
          },
        );
      },
    );
  }

  Widget _buildLoginRow() {
    return Row(
      mainAxisAlignment: .center,
      spacing: ThemeConstants.spaceXS,
      children: [
        AppText(
          context.translate(LanguageLabelKeys.alreadyHaveAccount),
          style: context.tt.bodyMedium?.copyWith(
            color: context.cs.onSurfaceVariant,
          ),
        ),
        GestureDetector(
          onTap: () => AppNavigator.pop(context),
          child: AppText(
            context.translate(LanguageLabelKeys.signIn),
            style: context.tt.bodyMedium?.copyWith(
              color: context.cs.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
