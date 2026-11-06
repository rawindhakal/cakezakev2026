import 'dart:io';
import 'package:customer/commons/widgets/app_network_image.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/features/auth/cubits/auth_cubit.dart';
import 'package:customer/features/profile/cubit/profile_update_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:customer/commons/widgets/api_country_phone_field.dart';
import 'package:customer/commons/widgets/country_dropdown_field.dart';
import 'package:customer/commons/cubit/countries_cubit.dart';
import 'package:customer/commons/models/countries_model.dart';
import '../cubit/profile_detail_cubit.dart';
import '../../../commons/widgets/app_button.dart';
import '../../../commons/widgets/app_text_field.dart';
import '../../../commons/widgets/custom_app_bar.dart';
import '../../../utils/input_validators.dart';
import '../../../utils/extensions/context_extensions.dart';
import '../../../utils/extensions/localization_extensions.dart';
import '../../../utils/extensions/size_extensions.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/utils/show_app_bottom_sheet.dart';
import 'package:customer/commons/animations/slide_animation.dart';
import 'package:customer/core/constants/theme_constants.dart';
import '../../../commons/widgets/app_text.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _scrollController = ScrollController();

  File? _profileImage;
  String? _profileImageUrl;
  String _phoneNumberOnly = '';
  CountriesData? _selectedCountry;
  bool _countryPrefilled = false;

  String? get _authType => AuthHiveBox.instance.userData?.type;
  bool get _isEmailReadOnly =>
      _authType == AuthType.google.name ||
      _authType == AuthType.apple.name ||
      _authType == AuthType.email.name;
  bool get _isPhoneReadOnly => _authType == AuthType.phone.name;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadCurrentProfile(ProfileDetailState state) {
    if (state is ProfileDetailLoaded) {
      final user = state.profile.data;
      if (_usernameController.text.isEmpty) {
        _usernameController.text = user?.name ?? '';
        _mobileController.text = user?.mobile ?? '';
        _emailController.text = user?.email ?? '';
        _profileImageUrl = user?.profile;
      }
    }
  }

  void _prefillCountry(BuildContext context, int? countryId) {
    if (_countryPrefilled) return;
    final countriesState = context.read<CountriesCubit>().state;
    if (countriesState is! CountriesLoaded) return;
    final countries = countriesState.countries;

    final byId = countryId == null
        ? null
        : countries.where((c) => c.id == countryId).toList();
    if (byId != null && byId.isNotEmpty) {
      _countryPrefilled = true;
      setState(() => _selectedCountry = byId.first);
      return;
    }

    final byDefault = findDefaultCountry(countries);
    if (byDefault != null) {
      _countryPrefilled = true;
      setState(() => _selectedCountry = byDefault);
    }
  }

  void _updateProfile(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    context.read<ProfileUpdateCubit>().updateProfile(
      name: _usernameController.text.trim(),
      mobile: _phoneNumberOnly.isNotEmpty
          ? _phoneNumberOnly
          : _mobileController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      profileImagePath: _profileImage?.path,
      countryId: _selectedCountry?.id?.toString(),
      countryCode: _selectedCountry?.dialCode,
    );
  }

  Future<void> _pickImage() async {
    final source = await showAppBottomSheet<ImageSource>(
      context,
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: ThemeConstants.paddingS,
      ),
      builder: (ctx) => SlideAnimationList(
        children: [
          ListTile(
            leading: AppSvgIcon(
              AssetsConstants.cameraIcon,
              size: ThemeConstants.iconL,
              color: context.cs.onSurfaceVariant,
            ),
            title: AppText(context.translate(LanguageLabelKeys.takePhoto)),
            onTap: () => AppNavigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: AppSvgIcon(
              AssetsConstants.galleryIcon,
              size: ThemeConstants.iconL,
              color: context.cs.onSurfaceVariant,
            ),
            title: AppText(
              context.translate(LanguageLabelKeys.chooseFromGallery),
            ),
            onTap: () => AppNavigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    );

    if (source == null) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked == null) return;
    if (!mounted) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressQuality: 85,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: context.translate(LanguageLabelKeys.cropPhoto),
          toolbarColor: context.cs.primary,
          toolbarWidgetColor: context.cs.onPrimary,
          activeControlsWidgetColor: context.cs.primary,
          lockAspectRatio: true,
          hideBottomControls: true,
        ),
        IOSUiSettings(
          title: context.translate(LanguageLabelKeys.cropPhoto),
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );
    if (cropped != null) {
      setState(() {
        _profileImage = File(cropped.path);
        _profileImageUrl = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(
        title: context.translate(LanguageLabelKeys.editProfile),
        scrollController: _scrollController,
      ),
      bottomNavigationBar:
          BlocSelector<ProfileUpdateCubit, ProfileUpdateState, bool>(
            selector: (state) => state is ProfileUpdateLoading,
            builder: (context, isLoading) =>
                _buildBottomButton(context, isLoading),
          ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<ProfileUpdateCubit, ProfileUpdateState>(
            listener: (context, state) {
              if (state is ProfileUpdateLoaded) {
                AppSnackBar.show(
                  context: context,
                  message: context.translate(
                    LanguageLabelKeys.profileUpdatedSuccess,
                  ),
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
          ),
          BlocListener<ProfileDetailCubit, ProfileDetailState>(
            listener: (context, state) {
              setState(() => _loadCurrentProfile(state));
              if (state is ProfileDetailLoaded) {
                _prefillCountry(context, state.profile.data?.countryId);
              }
            },
          ),
          BlocListener<CountriesCubit, CountriesState>(
            listener: (context, state) {
              if (state is CountriesLoaded) {
                final user = context.read<ProfileDetailCubit>().state;
                if (user is ProfileDetailLoaded) {
                  _prefillCountry(context, user.profile.data?.countryId);
                }
              }
            },
          ),
        ],
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsetsDirectional.fromSTEB(
            ThemeConstants.paddingXXL,
            ThemeConstants.spaceXXXL,
            ThemeConstants.paddingXXL,
            ThemeConstants.paddingL,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                Center(child: _buildProfileAvatar()),
                AppSpacing.h32,
                AppTextField(
                  controller: _usernameController,
                  labelText: context.translate(LanguageLabelKeys.fullName),
                  hintText: context.translate(LanguageLabelKeys.enterFullName),
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]')),
                  ],
                  validator: (v) => v.validateName(context),
                ),
                AppSpacing.h16,
                AppTextField(
                  controller: _emailController,
                  labelText: context.translate(LanguageLabelKeys.email),
                  hintText: context.translate(LanguageLabelKeys.enterEmail),
                  keyboardType: TextInputType.emailAddress,
                  readOnly: _isEmailReadOnly,
                  validator: (v) => v.validateEmail(context, required: false),
                ),
                AppSpacing.h16,
                ApiCountryPhoneField(
                  controller: _mobileController,
                  selectedCountry: _selectedCountry,
                  labelText: context.translate(LanguageLabelKeys.mobileNumber),
                  hintText: context.translate(
                    LanguageLabelKeys.enterPhoneNumber,
                  ),
                  readOnly: _isPhoneReadOnly,
                  validator: (v) => v.validateMobile(
                    context,
                    minLength: _selectedCountry?.minMobileLength ?? 10,
                    required: _authType == AuthType.phone.name,
                  ),
                  onCountryChanged: (country) => setState(() {
                    _selectedCountry = country;
                  }),
                  onChanged: (number) {
                    _phoneNumberOnly = number;
                  },
                ),
                AppSpacing.h16,
                CountryDropdownField(
                  selected: _selectedCountry,
                  labelText: context.translate(LanguageLabelKeys.country),
                  hintText: context.translate(LanguageLabelKeys.enterCountry),
                  onChanged: (country) =>
                      setState(() => _selectedCountry = country),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileAvatar() {
    final hasLocalImage = _profileImage != null;
    final hasNetworkImage =
        _profileImageUrl != null && _profileImageUrl!.isNotEmpty;

    return GestureDetector(
      onTap: _pickImage,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: AppDecorations.box(
              shape: .circle,
              color: context.cs.primaryContainer,
              border: Border.all(
                color: context.cs.primary.withValues(alpha: 0.25),
                width: 3,
              ),
            ),
            child: ClipOval(
              child: hasLocalImage
                  ? Image.file(_profileImage!, fit: BoxFit.cover)
                  : hasNetworkImage
                  ? AppNetworkImage(
                      url: _profileImageUrl!,
                      placeholder: AppSvgIcon(
                        AssetsConstants.userIcon,
                        size: ThemeConstants.iconXL,
                        color: context.cs.primary,
                        fit: BoxFit.scaleDown,
                      ),
                      errorWidget: AppSvgIcon(
                        AssetsConstants.userIcon,
                        size: ThemeConstants.iconXL,
                        color: context.cs.primary,
                        fit: BoxFit.scaleDown,
                      ),
                    )
                  : AppSvgIcon(
                      AssetsConstants.userIcon,
                      size: ThemeConstants.iconXL,
                      color: context.cs.primary,
                      fit: BoxFit.scaleDown,
                    ),
            ),
          ),
          PositionedDirectional(
            bottom: 0,
            end: 0,
            child: Container(
              width: 32,
              height: 32,
              decoration: AppDecorations.box(
                shape: .circle,
                color: context.cs.primary,
                border: Border.all(color: context.cs.surface, width: 2),
              ),
              padding: const EdgeInsetsDirectional.all(
                ThemeConstants.paddingXS,
              ),
              child: AppSvgIcon(
                AssetsConstants.cameraIcon,
                size: ThemeConstants.iconL,
                color: context.cs.onPrimary,
                fit: BoxFit.scaleDown,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton(BuildContext context, bool isLoading) {
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(
        ThemeConstants.paddingXL,
        ThemeConstants.paddingM,
        ThemeConstants.paddingXL,
        ThemeConstants.paddingM + context.bottomSafePadding,
      ),
      decoration: AppDecorations.box(
        color: context.cs.surface,
        boxShadow: [
          BoxShadow(
            color: context.cs.scrim.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: AppButton(
        label: context.translate(LanguageLabelKeys.updateProfile),
        onPressed: () => _updateProfile(context),
        isLoading: isLoading,
      ),
    );
  }
}
