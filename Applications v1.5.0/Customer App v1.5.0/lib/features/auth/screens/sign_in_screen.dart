import 'dart:io';
import 'package:customer/commons/widgets/custom_app_bar.dart';

import '../../../commons/widgets/app_text.dart';

import 'package:customer/commons/models/app_settings_model.dart';
import 'package:customer/commons/widgets/api_country_phone_field.dart';
import 'package:customer/commons/widgets/loading_widget.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/features/auth/screens/sign_up_screen.dart';
import 'package:customer/features/auth/screens/otp_verification_screen.dart';
import 'package:customer/features/auth/screens/forgot_password_screen.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/commons/cubit/countries_cubit.dart';
import 'package:customer/commons/models/countries_model.dart';
import 'package:customer/features/auth/cubits/auth_cubit.dart';
import 'package:customer/features/auth/cubits/sign_in_cubit.dart';
import 'package:customer/features/auth/cubits/custom_sms_send_phone_otp_cubit.dart';
import 'package:customer/commons/widgets/app_pill_tab_bar.dart';
import 'package:customer/features/auth/widgets/auth_screen_header.dart';
import 'package:customer/features/auth/widgets/auth_social_buttons.dart';
import 'package:customer/features/auth/widgets/auth_terms_bar.dart';
import 'package:customer/features/auth/widgets/sign_in_email_form.dart';
import 'package:customer/features/auth/models/enums/sign_in_enums.dart';
import 'package:customer/features/auth/widgets/sign_in_phone_form.dart';
import 'package:customer/features/cart/cubit/guest_cart_sync_helper.dart';
import 'package:customer/commons/cubit/settings_cubit.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/core/constants/theme_constants.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _emailPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _phonePasswordController = TextEditingController();
  final _scrollController = ScrollController();

  SignInMode _mode = SignInMode.email;
  bool _modeInitialized = false;
  String _fullPhoneNumber = '';
  String _countryCode = '';
  CountriesData? _selectedCountry;
  String? _phoneError;
  AppSettingsData? _settings;
  TabController? _tabController;
  String? _activeProvider;

  @override
  void dispose() {
    _emailController.dispose();
    _emailPasswordController.dispose();
    _phoneController.dispose();
    _phonePasswordController.dispose();
    _tabController?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    final controller = _tabController;
    if (controller == null || controller.indexIsChanging) return;
    _onModeChanged(controller.index == 0 ? SignInMode.phone : SignInMode.email);
  }

  bool get _isPhoneLogin => _settings?.phoneLogin == "1";
  bool get _isEmailLogin => _settings?.emailLogin == "1";
  bool get _isGoogleLogin => _settings?.googleLogin == "1";
  bool get _isAppleLogin => _settings?.appleLogin == "1";
  bool get _isFirebaseOtp => _settings?.firebaseAuthentication == "1";
  bool get _isCustomOtp => _settings?.customSmsGatewayOtpBased == "1";
  bool get _isPhonePassword => _settings?.phoneAuthPassword == "1";
  bool get _hasSocial => _isGoogleLogin || (Platform.isIOS && _isAppleLogin);

  void _initModeIfNeeded(AppSettingsData settings) {
    _settings = settings;
    if (!_modeInitialized) {
      _modeInitialized = true;
      _countryCode = '';
      _mode = _isPhoneLogin ? SignInMode.phone : SignInMode.email;
      _tabController = TabController(
        length: 2,
        vsync: this,
        initialIndex: _mode == SignInMode.phone ? 0 : 1,
      )..addListener(_handleTabChange);
    }
    if (_selectedCountry == null) {
      final countriesState = context.read<CountriesCubit>().state;
      if (countriesState is CountriesLoaded) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _prefillDefaultCountry(countriesState.countries),
        );
      }
    }
  }

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

  void _onModeChanged(SignInMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _phoneError = null;
      _formKey.currentState?.reset();
      _phoneController.clear();
      _fullPhoneNumber = '';
    });
  }

  void _onSubmit() {
    if (!_formKey.currentState!.validate()) return;
    _activeProvider = null;
    final languageId = SettingsHiveBox.instance.languageId;

    if (_mode == SignInMode.email) {
      context.read<SignInCubit>().loginWithEmailPassword(
        id: _emailController.text.trim(),
        password: _emailPasswordController.text,
        type: AuthType.email.name,
        languageId: languageId,
      );
    } else {
      if (_fullPhoneNumber.isEmpty) {
        setState(
          () => _phoneError = context.translate(
            LanguageLabelKeys.pleaseEnterPhoneNumber,
          ),
        );
        return;
      }
      setState(() => _phoneError = null);
      if (_isPhonePassword) {
        context.read<SignInCubit>().loginWithPhonePassword(
          id: _phoneController.text,
          password: _phonePasswordController.text,
          type: AuthType.phone.name,
          phoneAuthType: PhoneAuthType.password.apiValue,
          countryCode: _countryCode,
          languageId: languageId,
        );
      } else if (_isFirebaseOtp) {
        context.read<SignInCubit>().sendPhoneOtp(
          phoneNumber: _phoneController.text,
          countryCode: _countryCode,
        );
      } else if (_isCustomOtp) {
        context.read<CustomSmsSendPhoneOtpCubit>().customSmsSendPhoneOtp(
          phoneNumber: "$_countryCode$_fullPhoneNumber",
        );
      }
    }
  }

  void _onGoogleSignIn() {
    setState(() => _activeProvider = AuthType.google.name);
    context.read<SignInCubit>().loginWithGoogle(
      type: AuthType.google.name,
      languageId: SettingsHiveBox.instance.languageId,
    );
  }

  void _onAppleSignIn() {
    setState(() => _activeProvider = AuthType.apple.name);
    context.read<SignInCubit>().loginWithApple(
      type: AuthType.apple.name,
      languageId: SettingsHiveBox.instance.languageId,
    );
  }

  String _buttonLabel() {
    if (_mode == SignInMode.email || _isPhonePassword) {
      return context.translate(LanguageLabelKeys.signIn);
    }
    return context.translate(LanguageLabelKeys.sendOtp);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settingsState) {
        if (settingsState is SettingsInitial ||
            settingsState is SettingsLoading) {
          return const AppScaffold(body: LoadingWidget());
        }
        if (settingsState is SettingsError) {
          return AppScaffold(
            body: Center(child: AppText(settingsState.message)),
          );
        }
        _initModeIfNeeded((settingsState as SettingsLoaded).settings.data!);

        return MultiBlocListener(
          listeners: [
            BlocListener<SignInCubit, SignInState>(
              listener: (context, state) {
                if (state is SignInLoaded) {
                  GuestCartSyncHelper.syncAndNavigate(context);
                } else if (state is SignInUserNotFound) {
                  final AuthType authType;
                  if (state.phone != null) {
                    authType = AuthType.phone;
                  } else if (state.provider == AuthType.google.name) {
                    authType = AuthType.google;
                  } else if (state.provider == AuthType.apple.name) {
                    authType = AuthType.apple;
                  } else {
                    authType = AuthType.email;
                  }
                  AppNavigator.pushNamed(
                    context,
                    RouteNames.register,
                    arguments: RegisterArgs(
                      mode: authType,
                      email: state.email,
                      name: state.name,
                      phone: state.phone,
                    ),
                  );
                } else if (state is SignInInitial &&
                    _mode == SignInMode.phone) {
                  AppNavigator.pushNamed(
                    context,
                    RouteNames.otpVerification,
                    arguments: OtpVerificationArgs(
                      phone: _phoneController.text,
                      authType: OtpAuthType.firebase.name,
                      countryCode: _countryCode,
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
              CustomSmsSendPhoneOtpCubit,
              CustomSmsSendPhoneOtpState
            >(
              listener: (context, state) {
                if (state is CustomSmsSendPhoneOtpLoaded) {
                  AppNavigator.pushNamed(
                    context,
                    RouteNames.otpVerification,
                    arguments: OtpVerificationArgs(
                      phone: _phoneController.text,
                      authType: OtpAuthType.custom.name,
                      countryCode: _countryCode,
                    ),
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
            BlocListener<CountriesCubit, CountriesState>(
              listener: (context, state) {
                if (state is CountriesLoaded) {
                  _prefillDefaultCountry(state.countries);
                }
              },
            ),
          ],
          child: AppScaffold(
            appBar: CustomAppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              showBackButton: false,
              scrollController: _scrollController,
              actions: [_buildSkipButton()],
            ),
            bottomNavigationBar: const AuthTermsBar(),
            body: BlocBuilder<SignInCubit, SignInState>(
              builder: (context, signInState) {
                return BlocBuilder<
                  CustomSmsSendPhoneOtpCubit,
                  CustomSmsSendPhoneOtpState
                >(
                  builder: (context, customSmsState) {
                    final isLoading =
                        signInState is SignInLoading ||
                        customSmsState is CustomSmsSendPhoneOtpLoading;
                    return SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: ThemeConstants.paddingXXL,
                      ),
                      child: Column(
                        crossAxisAlignment: .stretch,
                        children: [
                          AppSpacing.h8,
                          AuthScreenHeader(
                            title: context.translate(
                              LanguageLabelKeys.welcomeBack,
                            ),
                            subtitle: context.translate(
                              LanguageLabelKeys.signInToContinue,
                            ),
                          ),
                          AppSpacing.h36,
                          if (_isEmailLogin &&
                              _isPhoneLogin &&
                              _tabController != null) ...[
                            AppPillTabBar(
                              controller: _tabController!,
                              tabs: [
                                context.translate(LanguageLabelKeys.mobile),
                                context.translate(LanguageLabelKeys.email),
                              ],
                            ),
                            AppSpacing.h24,
                          ],
                          if (_isEmailLogin || _isPhoneLogin) ...[
                            Form(
                              key: _formKey,
                              child: _mode == SignInMode.email
                                  ? SignInEmailForm(
                                      emailController: _emailController,
                                      passwordController:
                                          _emailPasswordController,
                                      onForgotPassword: () =>
                                          showForgotPasswordSheet(
                                            context,
                                            type: AuthType.email.name,
                                          ),
                                    )
                                  : SignInPhoneForm(
                                      phoneController: _phoneController,
                                      passwordController:
                                          _phonePasswordController,
                                      isPhonePasswordEnabled: _isPhonePassword,
                                      phoneError: _phoneError,
                                      selectedCountry: _selectedCountry,
                                      onPhoneChanged: (number, code) =>
                                          setState(() {
                                            _fullPhoneNumber = number;
                                            _countryCode = code;
                                            if (_phoneError != null &&
                                                number.isNotEmpty) {
                                              _phoneError = null;
                                            }
                                          }),
                                      onCountryChanged: (country) =>
                                          setState(() {
                                            _selectedCountry = country;
                                            _countryCode = formatDialCode(
                                              country.dialCode,
                                            );
                                          }),
                                      onForgotPassword: () =>
                                          showForgotPasswordSheet(
                                            context,
                                            type: AuthType.phone.name,
                                          ),
                                    ),
                            ),
                            AppSpacing.h24,
                            AppButton(
                              label: _buttonLabel(),
                              onPressed: isLoading ? null : _onSubmit,
                              isLoading: isLoading && _activeProvider == null,
                            ),
                          ],
                          if (_hasSocial) ...[
                            AppSpacing.h28,
                            if (_isEmailLogin || _isPhoneLogin) _buildDivider(),
                            AppSpacing.h20,
                            AuthSocialButtons(
                              isGoogleEnabled: _isGoogleLogin,
                              isAppleEnabled: _isAppleLogin,
                              onGoogleSignIn: _onGoogleSignIn,
                              onAppleSignIn: _onAppleSignIn,
                              isLoading: isLoading,
                              isGoogleLoading:
                                  isLoading &&
                                  _activeProvider == AuthType.google.name,
                              isAppleLoading:
                                  isLoading &&
                                  _activeProvider == AuthType.apple.name,
                            ),
                          ],
                          AppSpacing.h32,
                          _buildSignUpRow(),
                          AppSpacing.h16,
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkipButton() {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: ThemeConstants.paddingL),
      child: AppButton(
        label: context.translate(LanguageLabelKeys.skip),
        onPressed: () => AppNavigator.pushReplacementNamed(
          context,
          SettingsHiveBox.instance.hasLocation
              ? RouteNames.main
              : RouteNames.locationRequired,
        ),
        variant: AppButtonVariant.outline,
        fullWidth: false,
        height: 34,
        fontSize: 13,
        color: context.cs.onSurface,
        backgroundColor: context.cs.surface,
        borderColor: context.cs.outline,
        contentPadding: const EdgeInsetsDirectional.symmetric(
          horizontal: ThemeConstants.paddingL,
        ),
        borderRadius: AppRadius.r20,
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: context.cs.outlineVariant)),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: ThemeConstants.paddingL,
          ),
          child: AppText(
            context.translate(LanguageLabelKeys.orContinueWith),
            style: context.tt.bodySmall?.copyWith(
              color: context.cs.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Divider(color: context.cs.outlineVariant)),
      ],
    );
  }

  Widget _buildSignUpRow() {
    return Row(
      mainAxisAlignment: .center,
      children: [
        AppText(
          '${context.translate(LanguageLabelKeys.dontHaveAccount)} ',
          style: context.tt.bodyMedium?.copyWith(
            color: context.cs.onSurfaceVariant,
          ),
        ),
        GestureDetector(
          onTap: () => AppNavigator.pushNamed(
            context,
            RouteNames.register,
            arguments: RegisterArgs(
              mode: _mode == SignInMode.email ? AuthType.email : AuthType.phone,
            ),
          ),
          child: AppText(
            context.translate(LanguageLabelKeys.signUp),
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
