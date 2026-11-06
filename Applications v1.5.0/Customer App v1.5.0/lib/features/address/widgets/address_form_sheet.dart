import 'package:customer/core/constants/navigation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/commons/widgets/api_country_phone_field.dart';
import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/features/address/cubit/address_cubit.dart';
import 'package:customer/commons/cubit/countries_cubit.dart';
import 'package:customer/commons/cubit/regions_cubit.dart';
import 'package:customer/features/address/cubit/save_address_cubit.dart';
import 'package:customer/features/address/models/address_model.dart';
import 'package:customer/commons/models/countries_model.dart';
import 'package:customer/commons/models/regions_model.dart';
import 'package:customer/commons/widgets/country_dropdown_field.dart';
import 'package:customer/commons/widgets/region_dropdown_field.dart';
import 'package:customer/commons/widgets/app_text_field.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/features/address/models/location_result.dart';
import 'package:customer/commons/animations/slide_animation.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'address_form/sheet_drag_handle.dart';
import 'address_form/sheet_header.dart';
import 'address_form/sheet_footer.dart';
import 'address_form/contact_details_section.dart';
import 'address_form/address_details_section.dart';
import 'address_form/address_type_section.dart';
import 'address_form/default_toggle_sheet.dart';
import 'address_form/save_button.dart';

class AddressFormSheet extends StatefulWidget {
  final AddressData? address;
  final LocationResult locationResult;
  final bool isEdit;
  final VoidCallback onSuccess;

  const AddressFormSheet({
    super.key,
    required this.locationResult,
    required this.isEdit,
    required this.onSuccess,
    this.address,
  });

  @override
  State<AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _altMobileCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _landmarkCtrl;
  late final TextEditingController _areaCtrl;
  late final TextEditingController _pincodeCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _countryCtrl;

  String _type = 'home';
  bool _isDefault = false;
  String _fullMobile = '';
  String _fullAltMobile = '';
  late String _mobileCountryCode;
  late String _altMobileCountryCode;
  CountriesData? _selectedMobileCountry;
  CountriesData? _selectedAltMobileCountry;
  bool _mobileCountryPrefilled = false;
  bool _altMobileCountryPrefilled = false;

  // Snapshotted once at init — whether these fields came pre-filled from the
  // saved address / map geocode, so later edits don't flip their lock state.
  late final bool _cityPrefilled;
  late final bool _pincodePrefilled;

  // Country/state (region) dropdown selection. [_regionId] is only ever set
  // by [_onRegionSelected] (dropdown pick) and cleared on country change, so
  // it naturally stays null when the state was typed into the manual
  // fallback field instead — the request only carries `region_id` when it's
  // non-null.
  final RegionsCubit _regionsCubit = RegionsCubit();
  CountriesData? _selectedCountry;
  RegionsData? _selectedRegion;
  int? _regionId;
  bool _regionAutoMatchAttempted = false;

  // The country/state names to auto-match against the country/regions apis
  // once they load — captured once from the saved address or map geocode.
  late final String _initialCountryTarget;
  late final String _initialStateTarget;

  @override
  void initState() {
    super.initState();
    final a = widget.address;
    final loc = widget.locationResult;
    final sessionName = AuthHiveBox.instance.userName;
    final sessionMobile = AuthHiveBox.instance.userMobile;
    _nameCtrl = TextEditingController(
      text: (a?.name ?? '').isNotEmpty ? a!.name! : sessionName,
    );
    _mobileCtrl = TextEditingController(
      text: (a?.mobile ?? '').isNotEmpty ? a!.mobile! : sessionMobile,
    );
    _fullMobile = _mobileCtrl.text;
    _altMobileCtrl = TextEditingController(text: a?.alternateMobile ?? '');
    _fullAltMobile = _altMobileCtrl.text;
    _addressCtrl = TextEditingController(
      text: (a?.address ?? '').isNotEmpty
          ? a!.address!
          : loc.road.isNotEmpty
          ? loc.road
          : loc.formattedAddress,
    );
    _landmarkCtrl = TextEditingController(text: a?.landmark ?? '');
    _areaCtrl = TextEditingController(
      text: (a?.area ?? '').isNotEmpty ? a!.area! : loc.area,
    );
    _pincodeCtrl = TextEditingController(
      text: (a?.pincode ?? '').isNotEmpty ? a!.pincode! : loc.pincode,
    );
    _cityCtrl = TextEditingController(
      text: (a?.city ?? '').isNotEmpty ? a!.city! : loc.city,
    );
    _stateCtrl = TextEditingController(
      text: (a?.state ?? '').isNotEmpty ? a!.state! : loc.state,
    );
    _countryCtrl = TextEditingController(
      text: (a?.country ?? '').isNotEmpty ? a!.country! : loc.country,
    );
    _cityPrefilled = _cityCtrl.text.trim().isNotEmpty;
    _pincodePrefilled = _pincodeCtrl.text.trim().isNotEmpty;
    _initialCountryTarget = _countryCtrl.text.trim();
    _initialStateTarget = _stateCtrl.text.trim();
    _type = a?.type ?? 'home';
    _isDefault = a?.isDefault == '1';
    const defaultDialCode = '';
    _mobileCountryCode = (a?.countryCode ?? '').isNotEmpty
        ? a!.countryCode!
        : defaultDialCode;
    _altMobileCountryCode = (a?.alternateCountryCode ?? '').isNotEmpty
        ? a!.alternateCountryCode!
        : defaultDialCode;

    final countriesState = context.read<CountriesCubit>().state;
    if (countriesState is CountriesLoaded) {
      _prefillCountries(countriesState.countries, useSetState: false);
      _prefillAddressCountry(countriesState.countries, useSetState: false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _altMobileCtrl.dispose();
    _addressCtrl.dispose();
    _landmarkCtrl.dispose();
    _areaCtrl.dispose();
    _pincodeCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _countryCtrl.dispose();
    _regionsCubit.close();
    super.dispose();
  }

  /// Called once from [initState] (list may already be cached) and again from
  /// the [CountriesCubit] listener once the api response arrives.
  void _prefillCountries(
    List<CountriesData> countries, {
    bool useSetState = true,
  }) {
    final mobileMatch = !_mobileCountryPrefilled
        ? (_mobileCountryCode.isNotEmpty
              ? findCountryByDialCode(countries, _mobileCountryCode)
              : findDefaultCountry(countries))
        : null;
    final altMatch = !_altMobileCountryPrefilled
        ? (_altMobileCountryCode.isNotEmpty
              ? findCountryByDialCode(countries, _altMobileCountryCode)
              : findDefaultCountry(countries))
        : null;
    if (mobileMatch == null && altMatch == null) return;

    void apply() {
      if (mobileMatch != null) {
        _mobileCountryPrefilled = true;
        _selectedMobileCountry = mobileMatch;
        _mobileCountryCode = formatDialCode(mobileMatch.dialCode);
      }
      if (altMatch != null) {
        _altMobileCountryPrefilled = true;
        _selectedAltMobileCountry = altMatch;
        _altMobileCountryCode = formatDialCode(altMatch.dialCode);
      }
    }

    if (useSetState) {
      setState(apply);
    } else {
      apply();
    }
  }

  /// Auto-selects the address's country in the dropdown by matching
  /// [_initialCountryTarget] (the saved address / map geocode country name)
  /// against the loaded countries, then kicks off the region fetch for it.
  /// Called once from [initState] and again from the [CountriesCubit]
  /// listener, same as [_prefillCountries].
  void _prefillAddressCountry(
    List<CountriesData> countries, {
    bool useSetState = true,
  }) {
    if (_selectedCountry != null || _initialCountryTarget.isEmpty) return;
    CountriesData? match;
    for (final c in countries) {
      if ((c.name ?? '').trim().toLowerCase() ==
          _initialCountryTarget.toLowerCase()) {
        match = c;
        break;
      }
    }
    if (match == null) return;
    final selected = match;
    if (useSetState) {
      setState(() => _selectedCountry = selected);
    } else {
      _selectedCountry = selected;
    }
    if (selected.id != null) _regionsCubit.fetchRegions(selected.id!);
  }

  void _onCountrySelected(CountriesData country) {
    final changed = _selectedCountry?.id != country.id;
    setState(() {
      _selectedCountry = country;
      _countryCtrl.text = country.name ?? _countryCtrl.text;
      if (changed) {
        _selectedRegion = null;
        _regionId = null;
        _stateCtrl.clear();
        _regionAutoMatchAttempted = false;
      }
    });
    if (changed && country.id != null) _regionsCubit.fetchRegions(country.id!);
  }

  void _onRegionSelected(RegionsData region) {
    setState(() {
      _selectedRegion = region;
      _regionId = region.id;
      _stateCtrl.text = region.name ?? '';
    });
  }

  /// Auto-selects the region matching [_initialStateTarget] once the regions
  /// for the selected country load — only attempted once per country so a
  /// deliberate user pick is never overwritten by a later rebuild.
  void _onRegionsChanged(RegionsState state) {
    if (state is! RegionsLoaded || _regionAutoMatchAttempted) return;
    _regionAutoMatchAttempted = true;
    if (_initialStateTarget.isEmpty) return;
    RegionsData? match;
    for (final r in state.regions) {
      if ((r.name ?? '').trim().toLowerCase() ==
          _initialStateTarget.toLowerCase()) {
        match = r;
        break;
      }
    }
    if (match == null) return;
    final region = match;
    setState(() {
      _selectedRegion = region;
      _regionId = region.id;
      _stateCtrl.text = region.name ?? '';
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final loc = widget.locationResult;
    SettingsHiveBox.instance.saveUserLocation(
      latitude: loc.latitude.toString(),
      longitude: loc.longitude.toString(),
      pincode: _pincodeCtrl.text.trim(),
    );
    final cubit = context.read<SaveAddressCubit>();
    final hasAltMobile = _altMobileCtrl.text.trim().isNotEmpty;
    final altMobile = !hasAltMobile
        ? null
        : _fullAltMobile.isNotEmpty
        ? _fullAltMobile
        : _altMobileCtrl.text.trim();
    final altCountryCode = hasAltMobile ? _altMobileCountryCode : null;
    if (widget.isEdit) {
      cubit.updateAddress(
        id: widget.address!.id!,
        name: _nameCtrl.text.trim(),
        mobile: _fullMobile.isNotEmpty ? _fullMobile : _mobileCtrl.text.trim(),
        countryCode: _mobileCountryCode,
        alternateMobile: altMobile,
        alternateCountryCode: altCountryCode,
        address: _addressCtrl.text.trim(),
        landmark: _landmarkCtrl.text.trim(),
        area: _areaCtrl.text.trim(),
        pincode: _pincodeCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        state: _stateCtrl.text.trim(),
        country: _countryCtrl.text.trim(),
        type: _type,
        latitude: loc.latitude.toString(),
        longitude: loc.longitude.toString(),
        isDefault: _isDefault,
        regionId: _regionId,
      );
    } else {
      cubit.addAddress(
        name: _nameCtrl.text.trim(),
        mobile: _fullMobile.isNotEmpty ? _fullMobile : _mobileCtrl.text.trim(),
        countryCode: _mobileCountryCode,
        alternateMobile: altMobile,
        alternateCountryCode: altCountryCode,
        address: _addressCtrl.text.trim(),
        landmark: _landmarkCtrl.text.trim(),
        area: _areaCtrl.text.trim(),
        pincode: _pincodeCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        state: _stateCtrl.text.trim(),
        country: _countryCtrl.text.trim(),
        type: _type,
        latitude: loc.latitude.toString(),
        longitude: loc.longitude.toString(),
        isDefault: _isDefault,
        regionId: _regionId,
      );
    }
  }

  void _onMobileCountryChanged(CountriesData country) => setState(() {
    _selectedMobileCountry = country;
    _mobileCountryCode = formatDialCode(country.dialCode);
  });

  void _onAltMobileCountryChanged(CountriesData country) => setState(() {
    _selectedAltMobileCountry = country;
    _altMobileCountryCode = formatDialCode(country.dialCode);
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RegionsCubit>.value(
      value: _regionsCubit,
      child: MultiBlocListener(
        listeners: [
          BlocListener<RegionsCubit, RegionsState>(
            listener: (context, state) => _onRegionsChanged(state),
          ),
          BlocListener<SaveAddressCubit, SaveAddressState>(
            listener: (context, state) {
              if (state is SaveAddressSuccess) {
                final addressCubit = context.read<AddressCubit>();
                final saved = state.address;
                // Update the list locally from the response; refetch only if the
                // API didn't return the saved address.
                if (saved != null) {
                  if (state.isEdit) {
                    addressCubit.updateLocally(saved);
                  } else {
                    addressCubit.addLocally(saved);
                  }
                } else {
                  addressCubit.refresh();
                }
                AppNavigator.pop(context);
                widget.onSuccess();
              } else if (state is SaveAddressError) {
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
                _prefillCountries(state.countries);
                _prefillAddressCountry(state.countries);
              }
            },
          ),
        ],
        child: Container(
          margin: EdgeInsetsDirectional.only(bottom: context.keyboardInset),
          constraints: BoxConstraints(maxHeight: context.screenHeight * 0.92),
          decoration: AppDecorations.bottomSheet(color: context.cs.surface),
          child: Column(
            crossAxisAlignment: .start,
            mainAxisSize: .min,
            children: [
              const SheetDragHandle(),
              SheetHeader(isEdit: widget.isEdit),
              Flexible(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      ThemeConstants.paddingXL,
                      ThemeConstants.paddingXS,
                      ThemeConstants.paddingXL,
                      ThemeConstants.paddingXL,
                    ),
                    child: SlideAnimationList(
                      crossAxisAlignment: .start,
                      spacing: ThemeConstants.spaceXL,
                      children: [
                        AddressDetailsSection(
                          addressCtrl: _addressCtrl,
                          landmarkCtrl: _landmarkCtrl,
                          areaCtrl: _areaCtrl,
                          cityCtrl: _cityCtrl,
                          pincodeCtrl: _pincodeCtrl,
                          cityPrefilled: _cityPrefilled,
                          pincodePrefilled: _pincodePrefilled,
                          countryField: CountryDropdownField(
                            selected: _selectedCountry,
                            labelText: context.translate(
                              LanguageLabelKeys.country,
                            ),
                            hintText: context.translate(
                              LanguageLabelKeys.enterCountry,
                            ),
                            onChanged: _onCountrySelected,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? context.translate(LanguageLabelKeys.required)
                                : null,
                          ),
                          stateField: BlocBuilder<RegionsCubit, RegionsState>(
                            builder: (context, state) {
                              if (state is RegionsLoaded &&
                                  state.regions.isNotEmpty) {
                                return RegionDropdownField(
                                  selected: _selectedRegion,
                                  labelText: context.translate(
                                    LanguageLabelKeys.stateLabel,
                                  ),
                                  hintText: context.translate(
                                    LanguageLabelKeys.selectYourState,
                                  ),
                                  onChanged: _onRegionSelected,
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                      ? context.translate(
                                          LanguageLabelKeys.required,
                                        )
                                      : null,
                                );
                              }
                              return AppTextField(
                                controller: _stateCtrl,
                                isRequired: true,
                                labelText: context.translate(
                                  LanguageLabelKeys.stateLabel,
                                ),
                                hintText: context.translate(
                                  LanguageLabelKeys.enterState,
                                ),
                                textCapitalization: TextCapitalization.words,
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? context.translate(
                                        LanguageLabelKeys.required,
                                      )
                                    : null,
                              );
                            },
                          ),
                        ),
                        ContactDetailsSection(
                          nameCtrl: _nameCtrl,
                          mobileCtrl: _mobileCtrl,
                          altMobileCtrl: _altMobileCtrl,
                          selectedMobileCountry: _selectedMobileCountry,
                          selectedAltMobileCountry: _selectedAltMobileCountry,
                          onMobileCountryChanged: _onMobileCountryChanged,
                          onAltMobileCountryChanged: _onAltMobileCountryChanged,
                          onMobileChanged: (number) => _fullMobile = number,
                          onAltMobileChanged: (number) =>
                              _fullAltMobile = number,
                        ),
                        AddressTypeSection(
                          selected: _type,
                          onChanged: (v) => setState(() => _type = v),
                        ),
                        DefaultToggleSheet(
                          value: _isDefault,
                          onChanged: (v) => setState(() => _isDefault = v),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SheetFooter(
                child: SaveButton(isEdit: widget.isEdit, onSubmit: _submit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
