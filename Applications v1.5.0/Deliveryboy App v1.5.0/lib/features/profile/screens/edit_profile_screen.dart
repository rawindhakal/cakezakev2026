import 'dart:io';
import 'package:deliveryboy/commons/widgets/app_scaffold.dart';
import 'package:deliveryboy/commons/widgets/collapse_on_scroll.dart';
import 'package:deliveryboy/core/local_storage/auth_hive_box.dart';
import 'package:deliveryboy/commons/cubit/countries_cubit.dart';
import 'package:deliveryboy/commons/cubit/zones_cubit.dart';
import 'package:deliveryboy/commons/models/countries_model.dart';
import 'package:deliveryboy/commons/models/earning_type.dart';
import 'package:deliveryboy/commons/models/zones_model.dart';
import 'package:deliveryboy/commons/widgets/country_phone_field.dart';
import 'package:deliveryboy/commons/widgets/app_snack_bar.dart';
import 'package:deliveryboy/features/profile/cubit/profile_update_cubit.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/profile_detail_cubit.dart';
import '../../../commons/widgets/custom_app_bar.dart';
import 'package:deliveryboy/core/constants/navigation_service.dart';
import '../widgets/edit_profile_step_indicator.dart';
import '../widgets/edit_profile_step1.dart';
import '../widgets/edit_profile_step2.dart';
import '../widgets/edit_profile_bottom_nav.dart';

/// Multi-step screen for editing the rider's personal and bank details.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _dobController = TextEditingController();
  final _mobileController = TextEditingController();
  final _addressController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ifscCodeController = TextEditingController();
  final _accountNameController = TextEditingController();
  final _commissionController = TextEditingController();
  final _bonusMinController = TextEditingController();
  final _bonusMaxController = TextEditingController();
  final _returnCommissionController = TextEditingController();
  final _returnBonusMinController = TextEditingController();
  final _returnBonusMaxController = TextEditingController();
  final _scrollController = ScrollController();

  File? _profileImage;
  String? _profileImageUrl;
  File? _nationalIdImage;
  File? _drivingLicenseImage;
  String? _nationalIdImageUrl;
  String? _drivingLicenseImageUrl;

  EarningType _earningType = EarningType.salaried;
  EarningType _returnEarningType = EarningType.salaried;
  String? _nationalIdError;
  String? _drivingLicenseError;
  CountriesData? _selectedCountry;
  bool _countryPrefilled = false;
  ZonesData? _selectedZone;
  bool _zonePrefilled = false;
  int? _profileZoneId;

  /// Owned here rather than created in [build] so the zone helpers below can
  /// reach it — this State's context sits above any provider build() inserts.
  final _zonesCubit = ZonesCubit();

  int _currentStep = 0;

  /// Email and bank fields are editable only while the API returns them blank;
  /// once saved they are locked.
  bool _emailLocked = false;
  bool _bankNameLocked = false;
  bool _accountNumberLocked = false;
  bool _ifscCodeLocked = false;
  bool _accountNameLocked = false;

  void _prefillCountry(BuildContext context, int? countryId) {
    if (_countryPrefilled) return;
    final countriesState = context.read<CountriesCubit>().state;
    if (countriesState is! CountriesLoaded ||
        countriesState.countries.isEmpty) {
      return;
    }
    final countries = countriesState.countries;
    CountriesData? match;
    if (countryId != null) {
      match = countries.where((c) => c.id == countryId).firstOrNull;
    }
    match ??= findDefaultCountry(countries) ?? countries.first;
    _countryPrefilled = true;
    _selectedCountry = match;
    _loadZonesOf(match);
  }

  /// Loads the zones of [country] once it is known. Deferred to the next frame
  /// because the country is resolved while the screen is building.
  void _loadZonesOf(CountriesData country) {
    final countryId = country.id?.toString();
    if (countryId == null || countryId.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _zonesCubit.fetchZones(countryId);
    });
  }

  /// Selects the rider's saved zone as soon as the zone list for their country arrives.
  void _prefillZone(List<ZonesData> zones) {
    if (_zonePrefilled) return;
    _zonePrefilled = true;
    setState(
      () => _selectedZone = zones
          .where((z) => z.id == _profileZoneId)
          .firstOrNull,
    );
  }

  /// Zone is mandatory, but only once the country actually offers zones.
  String? _validateZone(String? _) {
    final state = _zonesCubit.state;
    if (state is ZonesLoaded && state.zones.isEmpty) return null;
    if (_selectedZone != null) return null;
    return context
        .translate(LanguageLabelKeys.fieldRequired)
        .replaceAll('{field}', context.translate(LanguageLabelKeys.zone));
  }

  void _loadCurrentProfile(ProfileDetailState state) {
    if (state is ProfileDetailLoaded) {
      final profile = state.data;
      if (_usernameController.text.isEmpty) {
        _usernameController.text = profile.data?.name ?? '';
        _mobileController.text = profile.data?.mobile ?? '';
        _emailController.text = profile.data?.email ?? '';
        _bankNameController.text = profile.data?.bankName ?? '';
        _accountNumberController.text = profile.data?.bankAccountNumber ?? '';
        _ifscCodeController.text = profile.data?.ifscCode ?? '';
        _accountNameController.text = profile.data?.accountName ?? '';
        _emailLocked = _emailController.text.trim().isNotEmpty;
        _bankNameLocked = _bankNameController.text.trim().isNotEmpty;
        _accountNumberLocked = _accountNumberController.text.trim().isNotEmpty;
        _ifscCodeLocked = _ifscCodeController.text.trim().isNotEmpty;
        _accountNameLocked = _accountNameController.text.trim().isNotEmpty;
        if (profile.data?.bonusType == 1) {
          _earningType = EarningType.commission;
          _commissionController.text =
              profile.data?.bonusPercentage?.toString() ?? '';
          _bonusMinController.text =
              profile.data?.bonusMinAmount?.toString() ?? '';
          _bonusMaxController.text =
              profile.data?.bonusMaxAmount?.toString() ?? '';
        } else {
          _earningType = EarningType.salaried;
        }
        if (profile.data?.returnBonusType == 1) {
          _returnEarningType = EarningType.commission;
          _returnCommissionController.text =
              profile.data?.returnBonusPercentage?.toString() ?? '';
          _returnBonusMinController.text =
              profile.data?.returnBonusMinAmount?.toString() ?? '';
          _returnBonusMaxController.text =
              profile.data?.returnBonusMaxAmount?.toString() ?? '';
        } else {
          _returnEarningType = EarningType.salaried;
        }
        _dobController.text = profile.data?.dob ?? '';
        _profileImageUrl = profile.data?.profileUrl;
        _nationalIdImageUrl = profile.data?.nationalIdentityCardUrl;
        _drivingLicenseImageUrl = profile.data?.drivingLicenseUrl;
        _addressController.text = profile.data?.address ?? '';
      }
      _profileZoneId ??= profile.data?.zoneId;
      _prefillCountry(context, profile.data?.countryId);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _ifscCodeController.dispose();
    _accountNameController.dispose();
    _commissionController.dispose();
    _bonusMinController.dispose();
    _bonusMaxController.dispose();
    _returnCommissionController.dispose();
    _returnBonusMinController.dispose();
    _returnBonusMaxController.dispose();
    _zonesCubit.close();
    _scrollController.dispose();
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

  void _nextStep() {
    if (_step1FormKey.currentState!.validate()) {
      setState(() => _currentStep = 1);
    }
  }

  void _prevStep() {
    if (_currentStep == 1) {
      setState(() => _currentStep = 0);
    } else {
      AppNavigator.pop(context);
    }
  }

  void _updateProfile(BuildContext context) {
    if (!_step2FormKey.currentState!.validate()) return;
    context.read<ProfileUpdateCubit>().updateProfile(
      name: _usernameController.text.trim(),
      mobile: _mobileController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      dob: _dobController.text.trim().isEmpty
          ? null
          : _dobController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      bankName: _bankNameController.text.trim().isEmpty
          ? null
          : _bankNameController.text.trim(),
      bankAccountNumber: _accountNumberController.text.trim().isEmpty
          ? null
          : _accountNumberController.text.trim(),
      ifscCode: _ifscCodeController.text.trim().isEmpty
          ? null
          : _ifscCodeController.text.trim(),
      accountName: _accountNameController.text.trim().isEmpty
          ? null
          : _accountNameController.text.trim(),
      bonusType: _earningType == EarningType.commission ? '1' : '0',
      bonusPercentage: _commissionController.text.trim(),
      bonusMinAmount: _bonusMinController.text.trim(),
      bonusMaxAmount: _bonusMaxController.text.trim(),
      returnBonusType: _returnEarningType == EarningType.commission ? '1' : '0',
      returnBonusPercentage: _returnCommissionController.text.trim(),
      returnBonusMinAmount: _returnBonusMinController.text.trim(),
      returnBonusMaxAmount: _returnBonusMaxController.text.trim(),
      profileImagePath: _profileImage?.path,
      nationalIdImagePath: _nationalIdImage?.path,
      drivingLicenseImagePath: _drivingLicenseImage?.path,
      countryId: _selectedCountry?.id?.toString(),
      zoneId: _selectedZone?.id?.toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _zonesCubit,
      child: Builder(builder: _buildContent),
    );
  }

  Widget _buildContent(BuildContext context) {
    return BlocConsumer<ProfileUpdateCubit, ProfileUpdateState>(
      listener: (context, state) {
        if (state is ProfileUpdateLoaded) {
          if (state.data.data != null) {
            context.read<ProfileDetailCubit>().setProfile(state.data);
            AuthHiveBox.instance.updateUserData(auth: state.data);
          }
          AppSnackBar.show(
            context: context,
            message: context.translate(LanguageLabelKeys.profileUpdated),
            type: SnackBarType.success,
          );
          AppNavigator.pop(context);
        } else if (state is ProfileUpdateError) {
          AppSnackBar.show(
            context: context,
            message: state.message,
            type: SnackBarType.error,
          );
        }
      },
      builder: (context, updateState) {
        final profileDetailState = context.watch<ProfileDetailCubit>().state;
        _loadCurrentProfile(profileDetailState);
        final isLoading = updateState is ProfileUpdateLoading;

        return AppScaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          extendBody: false,
          applyBottomInset: false,
          appBar: CustomAppBar(
            title: context.translate(LanguageLabelKeys.editProfile),
            subtitle: _currentStep == 0
                ? context.translate(
                    LanguageLabelKeys.updatePersonalDetailsSubtitle,
                  )
                : context.translate(
                    LanguageLabelKeys.updateBankDetailsSubtitle,
                  ),
            currentStep: _currentStep,
            totalSteps: 2,
            scrollController: _scrollController,
            collapseOffset: 60,
            collapsedLeading: CollapsedAvatar(
              image: _profileImage,
              imageUrl: _profileImageUrl,
              onPicked: (f) => setState(() => _profileImage = f),
            ),
          ),
          bottomNavigationBar: EditProfileBottomNav(
            currentStep: _currentStep,
            isLoading: isLoading,
            onBack: _prevStep,
            onNext: _nextStep,
            onSubmit: () => _updateProfile(context),
          ),
          body: MultiBlocListener(
            listeners: [
              BlocListener<CountriesCubit, CountriesState>(
                listener: (context, state) {
                  if (state is CountriesLoaded) {
                    final countryId = profileDetailState is ProfileDetailLoaded
                        ? profileDetailState.data.data?.countryId
                        : null;
                    setState(() => _prefillCountry(context, countryId));
                  }
                },
              ),
              BlocListener<ZonesCubit, ZonesState>(
                listener: (context, state) {
                  if (state is ZonesLoaded) _prefillZone(state.zones);
                },
              ),
            ],
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: [
                  CollapseOnScroll(
                    controller: _scrollController,
                    collapseOffset: 60,
                    child: EditProfileStepIndicator(
                      currentStep: _currentStep,
                      profileImage: _profileImage,
                      profileImageUrl: _profileImageUrl,
                      onProfileImagePicked: (f) =>
                          setState(() => _profileImage = f),
                    ),
                  ),
                  _currentStep == 0
                      ? EditProfileStep1(
                          key: const ValueKey('step1'),
                          formKey: _step1FormKey,
                          usernameController: _usernameController,
                          emailController: _emailController,
                          emailReadOnly: _emailLocked,
                          dobController: _dobController,
                          mobileController: _mobileController,
                          addressController: _addressController,
                          commissionController: _commissionController,
                          bonusMinController: _bonusMinController,
                          bonusMaxController: _bonusMaxController,
                          returnCommissionController:
                              _returnCommissionController,
                          returnBonusMinController: _returnBonusMinController,
                          returnBonusMaxController: _returnBonusMaxController,
                          returnEarningType: _returnEarningType,
                          nationalIdImage: _nationalIdImage,
                          nationalIdImageUrl: _nationalIdImageUrl,
                          drivingLicenseImage: _drivingLicenseImage,
                          drivingLicenseImageUrl: _drivingLicenseImageUrl,
                          nationalIdError: _nationalIdError,
                          drivingLicenseError: _drivingLicenseError,
                          earningType: _earningType,
                          selectedCountry: _selectedCountry,
                          selectedZone: _selectedZone,
                          onZoneChanged: (z) =>
                              setState(() => _selectedZone = z),
                          zoneValidator: _validateZone,
                          onEarningTypeChanged: (v) =>
                              setState(() => _earningType = v),
                          onNationalIdPicked: (f) => setState(() {
                            _nationalIdImage = f;
                            _nationalIdImageUrl = null;
                            _nationalIdError = null;
                          }),
                          onDrivingLicensePicked: (f) => setState(() {
                            _drivingLicenseImage = f;
                            _drivingLicenseImageUrl = null;
                            _drivingLicenseError = null;
                          }),
                          onPickDob: _pickDob,
                        )
                      : EditProfileStep2(
                          key: const ValueKey('step2'),
                          formKey: _step2FormKey,
                          bankNameController: _bankNameController,
                          accountNumberController: _accountNumberController,
                          ifscCodeController: _ifscCodeController,
                          accountNameController: _accountNameController,
                          bankNameReadOnly: _bankNameLocked,
                          accountNumberReadOnly: _accountNumberLocked,
                          ifscCodeReadOnly: _ifscCodeLocked,
                          accountNameReadOnly: _accountNameLocked,
                        ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
