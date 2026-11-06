import 'dart:io';
import 'package:deliveryboy/commons/cubit/countries_cubit.dart';
import 'package:deliveryboy/commons/cubit/zones_cubit.dart';
import 'package:deliveryboy/commons/models/countries_model.dart';
import 'package:deliveryboy/commons/models/earning_type.dart';
import 'package:deliveryboy/commons/models/zones_model.dart';
import 'package:deliveryboy/commons/widgets/collapse_on_scroll.dart';
import 'package:deliveryboy/commons/widgets/country_phone_field.dart';
import 'package:deliveryboy/commons/widgets/earning_type_selector.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../commons/widgets/app_text_field.dart';
import '../../../commons/widgets/profile_avatar_picker.dart';
import '../../../utils/input_validators.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/core/constants/navigation_service.dart';
import 'register_credential_fields.dart';
import 'register_identity_docs.dart';
import '../../../commons/widgets/app_text.dart';

/// Registration form collecting delivery boy credentials and identity documents.
class RegisterForm extends StatefulWidget {
  final void Function({
    required String name,
    required String mobile,
    required String password,
    required String confirmPassword,
    required String email,
    required String dob,
    String? profileImagePath,
    String? nationalIdImagePath,
    String? drivingLicenseImagePath,
    required String bonusType,
    required String bonusPercentage,
    String? bonusMinAmount,
    String? bonusMaxAmount,
    required String returnBonusType,
    String? returnBonusPercentage,
    String? returnBonusMinAmount,
    String? returnBonusMaxAmount,
    String? countryId,
    String? countryCode,
    String? zoneId,
  })
  onRegister;

  final ScrollController? scrollController;
  final ValueChanged<File?>? onProfileImageChanged;

  const RegisterForm({
    super.key,
    required this.onRegister,
    this.scrollController,
    this.onProfileImageChanged,
  });

  @override
  State<RegisterForm> createState() => RegisterFormState();
}

class RegisterFormState extends State<RegisterForm> {
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _dobController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _commissionController = TextEditingController();
  final _bonusMinController = TextEditingController();
  final _bonusMaxController = TextEditingController();
  final _returnCommissionController = TextEditingController();
  final _returnBonusMinController = TextEditingController();
  final _returnBonusMaxController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  File? _profileImage;
  File? _nationalIdImage;
  File? _drivingLicenseImage;
  EarningType _earningType = EarningType.salaried;
  EarningType _returnEarningType = EarningType.salaried;
  String? _nationalIdError;
  String? _drivingLicenseError;
  CountriesData? _selectedCountry;
  ZonesData? _selectedZone;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<CountriesCubit>().state;
      if (state is CountriesLoaded &&
          state.countries.isNotEmpty &&
          _selectedCountry == null) {
        _selectCountry(
          findDefaultCountry(state.countries) ?? state.countries.first,
        );
      } else if (state is CountriesInitial) {
        context.read<CountriesCubit>().fetchCountries();
      }
    });
  }

  /// Applies the chosen country and reloads the zones that belong to it —
  /// any previously picked zone no longer applies, so it is cleared.
  void _selectCountry(CountriesData country) {
    final changed = _selectedCountry?.id != country.id;
    setState(() {
      _selectedCountry = country;
      if (changed) _selectedZone = null;
    });
    final countryId = country.id?.toString();
    if (countryId != null && countryId.isNotEmpty) {
      context.read<ZonesCubit>().fetchZones(countryId);
    } else {
      context.read<ZonesCubit>().reset();
    }
  }

  /// Zone is mandatory, but only once the country actually offers zones.
  String? _validateZone(String? _) {
    final state = context.read<ZonesCubit>().state;
    if (state is ZonesLoaded && state.zones.isEmpty) return null;
    if (_selectedZone != null) return null;
    return context
        .translate(LanguageLabelKeys.fieldRequired)
        .replaceAll('{field}', context.translate(LanguageLabelKeys.zone));
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _commissionController.dispose();
    _bonusMinController.dispose();
    _bonusMaxController.dispose();
    _returnCommissionController.dispose();
    _returnBonusMinController.dispose();
    _returnBonusMaxController.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: context.cs),
        child: child!,
      ),
    );
    if (picked != null) {
      _dobController.text =
          '${picked.year}/${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}';
    }
  }

  bool _validateImages() {
    setState(() {
      _nationalIdError = _nationalIdImage == null
          ? context.translate(LanguageLabelKeys.nationalIdRequired)
          : null;
      _drivingLicenseError = _drivingLicenseImage == null
          ? context.translate(LanguageLabelKeys.drivingLicenseRequired)
          : null;
    });
    return _nationalIdImage != null && _drivingLicenseImage != null;
  }

  void submit() {
    final imagesValid = _validateImages();
    if (!_formKey.currentState!.validate() || !imagesValid) return;
    widget.onRegister(
      name: _usernameController.text.trim(),
      mobile: _mobileController.text.trim(),
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
      email: _emailController.text.trim(),
      dob: _dobController.text.trim(),
      profileImagePath: _profileImage?.path,
      nationalIdImagePath: _nationalIdImage?.path,
      drivingLicenseImagePath: _drivingLicenseImage?.path,
      bonusType: _earningType == EarningType.commission ? '1' : '0',
      bonusPercentage: _earningType == EarningType.commission
          ? _commissionController.text.trim()
          : '',
      bonusMinAmount: _earningType == EarningType.commission
          ? _bonusMinController.text.trim()
          : null,
      bonusMaxAmount: _earningType == EarningType.commission
          ? _bonusMaxController.text.trim()
          : null,
      returnBonusType: _returnEarningType == EarningType.commission ? '1' : '0',
      returnBonusPercentage: _returnEarningType == EarningType.commission
          ? _returnCommissionController.text.trim()
          : null,
      returnBonusMinAmount: _returnEarningType == EarningType.commission
          ? _returnBonusMinController.text.trim()
          : null,
      returnBonusMaxAmount: _returnEarningType == EarningType.commission
          ? _returnBonusMaxController.text.trim()
          : null,
      countryId: _selectedCountry?.id?.toString(),
      countryCode: _selectedCountry?.dialCode,
      zoneId: _selectedZone?.id?.toString(),
    );
  }

  void setProfileImage(File f) {
    setState(() => _profileImage = f);
    widget.onProfileImageChanged?.call(f);
  }

  @override
  Widget build(BuildContext context) {
    final avatar = ProfileAvatarPicker(
      image: _profileImage,
      onPicked: (f) {
        setState(() => _profileImage = f);
        widget.onProfileImageChanged?.call(f);
      },
    );
    return BlocListener<CountriesCubit, CountriesState>(
      listener: (context, state) {
        if (state is CountriesLoaded &&
            state.countries.isNotEmpty &&
            _selectedCountry == null) {
          _selectCountry(
            findDefaultCountry(state.countries) ?? state.countries.first,
          );
        }
      },
      child: SingleChildScrollView(
        controller: widget.scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: ThemeConstants.paddingXXL,
                vertical: ThemeConstants.paddingL,
              ),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    Center(
                      child: widget.scrollController == null
                          ? avatar
                          : CollapseOnScroll(
                              controller: widget.scrollController!,
                              collapseOffset: 60,
                              child: avatar,
                            ),
                    ),
                    AppSpacing.h24,

                    RegisterCredentialFields(
                      nameController: _usernameController,
                      emailController: _emailController,
                      dobController: _dobController,
                      mobileController: _mobileController,
                      passwordController: _passwordController,
                      confirmPasswordController: _confirmPasswordController,
                      selectedCountry: _selectedCountry,
                      onCountryChanged: _selectCountry,
                      selectedZone: _selectedZone,
                      onZoneChanged: (z) => setState(() => _selectedZone = z),
                      zoneValidator: _validateZone,
                      onPickDob: _pickDob,
                      obscurePassword: _obscurePassword,
                      onToggleObscurePassword: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      obscureConfirm: _obscureConfirm,
                      onToggleObscureConfirm: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    AppSpacing.h14,

                    IdentityDocsSection(
                      nationalIdImage: _nationalIdImage,
                      nationalIdError: _nationalIdError,
                      onNationalIdPicked: (file) => setState(() {
                        _nationalIdImage = file;
                        _nationalIdError = null;
                      }),
                      drivingLicenseImage: _drivingLicenseImage,
                      drivingLicenseError: _drivingLicenseError,
                      onDrivingLicensePicked: (file) => setState(() {
                        _drivingLicenseImage = file;
                        _drivingLicenseError = null;
                      }),
                    ),
                    AppSpacing.h14,

                    _label(
                      context,
                      context.translate(LanguageLabelKeys.earningType),
                    ),
                    AppSpacing.h8,
                    EarningTypeSelector(
                      value: _earningType,
                      onChanged: (v) {
                        if (v != null) setState(() => _earningType = v);
                      },
                    ),
                    AppSpacing.h14,

                    if (_earningType == EarningType.commission) ...[
                      _label(
                        context,
                        context.translate(LanguageLabelKeys.commissionPercent),
                        isRequired: true,
                      ),
                      AppSpacing.h8,
                      AppTextField(
                        controller: _commissionController,
                        hintText: context.translate(
                          LanguageLabelKeys.enterCommission,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (v) => _earningType == EarningType.commission
                            ? v.validateCommission(context)
                            : null,
                      ),
                      AppSpacing.h14,
                      _MinMaxFields(
                        minController: _bonusMinController,
                        maxController: _bonusMaxController,
                        enabled: _earningType == EarningType.commission,
                      ),
                      AppSpacing.h14,
                    ],

                    _label(
                      context,
                      context.translate(LanguageLabelKeys.returnEarningType),
                    ),
                    AppSpacing.h8,
                    EarningTypeSelector(
                      value: _returnEarningType,
                      onChanged: (v) {
                        if (v != null) setState(() => _returnEarningType = v);
                      },
                    ),
                    AppSpacing.h14,

                    if (_returnEarningType == EarningType.commission) ...[
                      _label(
                        context,
                        context.translate(
                          LanguageLabelKeys.returnCommissionPercent,
                        ),
                        isRequired: true,
                      ),
                      AppSpacing.h8,
                      AppTextField(
                        controller: _returnCommissionController,
                        hintText: context.translate(
                          LanguageLabelKeys.enterCommission,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (v) =>
                            _returnEarningType == EarningType.commission
                            ? v.validateCommission(context)
                            : null,
                      ),
                      AppSpacing.h14,
                      _MinMaxFields(
                        minController: _returnBonusMinController,
                        maxController: _returnBonusMaxController,
                        enabled: _returnEarningType == EarningType.commission,
                      ),
                      AppSpacing.h14,
                    ],

                    AppSpacing.h10,

                    Center(
                      child: Row(
                        mainAxisAlignment: .center,
                        children: [
                          AppText(
                            context.translate(
                              LanguageLabelKeys.alreadyHaveAccount,
                            ),
                            style: context.tt.bodyMedium?.copyWith(
                              color: context.cs.onSurfaceVariant,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => AppNavigator.pop(context),
                            child: AppText(
                              context.translate(LanguageLabelKeys.login),
                              style: context.tt.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: context.cs.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.h24,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _label(BuildContext context, String text, {bool isRequired = false}) {
  return AppText(
    text,
    isRequired: isRequired,
    style: context.tt.labelMedium?.copyWith(color: context.cs.onSurface),
  );
}

/// Editable min/max bonus-amount pair shown under a commission block.
class _MinMaxFields extends StatelessWidget {
  final TextEditingController minController;
  final TextEditingController maxController;
  final bool enabled;

  const _MinMaxFields({
    required this.minController,
    required this.maxController,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            children: [
              _label(
                context,
                context.translate(LanguageLabelKeys.minAmount),
                isRequired: true,
              ),
              AppSpacing.h8,
              AppTextField(
                controller: minController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) => enabled
                    ? v.validateRequired(
                        context,
                        context.translate(LanguageLabelKeys.minAmount),
                      )
                    : null,
              ),
            ],
          ),
        ),
        AppSpacing.w12,
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            children: [
              _label(
                context,
                context.translate(LanguageLabelKeys.maxAmount),
                isRequired: true,
              ),
              AppSpacing.h8,
              AppTextField(
                controller: maxController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) => enabled
                    ? v.validateRequired(
                        context,
                        context.translate(LanguageLabelKeys.maxAmount),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
