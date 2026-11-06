import 'package:customer/commons/cubit/countries_cubit.dart';
import 'package:customer/commons/cubit/regions_cubit.dart';
import 'package:customer/commons/models/countries_model.dart';
import 'package:customer/commons/models/regions_model.dart';
import 'package:customer/commons/widgets/api_country_phone_field.dart';
import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/commons/widgets/app_text_field.dart';
import 'package:customer/commons/widgets/country_dropdown_field.dart';
import 'package:customer/commons/widgets/region_dropdown_field.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/features/checkout/models/billing_address_model.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/show_app_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens the billing-address form and resolves with the entered
/// [BillingAddressData], or `null` if the user dismissed the sheet without
/// saving. Pass [initial] to prefill/edit a previously entered address.
Future<BillingAddressData?> showBillingAddressSheet(
  BuildContext context, {
  BillingAddressData? initial,
}) {
  return showAppBottomSheet<BillingAddressData>(
    context,
    title: context.translate(LanguageLabelKeys.billingAddress),
    padding: const EdgeInsetsDirectional.fromSTEB(
      ThemeConstants.paddingL,
      ThemeConstants.paddingM,
      ThemeConstants.paddingL,
      ThemeConstants.paddingL,
    ),
    builder: (_) => _BillingAddressSheet(initial: initial),
  );
}

class _BillingAddressSheet extends StatefulWidget {
  const _BillingAddressSheet({this.initial});

  final BillingAddressData? initial;

  @override
  State<_BillingAddressSheet> createState() => _BillingAddressSheetState();
}

class _BillingAddressSheetState extends State<_BillingAddressSheet> {
  final _formKey = GlobalKey<FormState>();
  final RegionsCubit _regionsCubit = RegionsCubit();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _pincodeCtrl;
  late final TextEditingController _stateCtrl;

  CountriesData? _selectedCountry;
  RegionsData? _selectedRegion;

  /// Only set when [_selectedRegion] came from the dropdown — stays `null`
  /// while the state was typed into the manual fallback field instead (no
  /// `billing_state` request param exists to carry that text).
  int? _regionId;

  /// Guards [_onRegionsChanged] so a deliberate user pick is never overwritten
  /// by a later rebuild — matching only ever attempted once per country.
  bool _regionAutoMatchAttempted = false;

  /// Dial-code country for the mobile field — kept separate from
  /// [_selectedCountry] (the billing address's country) same as the address
  /// form does for its mobile field.
  CountriesData? _selectedMobileCountry;
  bool _mobileCountryPrefilled = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameCtrl = TextEditingController(text: initial?.name ?? '');
    _mobileCtrl = TextEditingController(text: initial?.mobile ?? '');
    _addressCtrl = TextEditingController(text: initial?.address ?? '');
    _cityCtrl = TextEditingController(text: initial?.city ?? '');
    _pincodeCtrl = TextEditingController(text: initial?.pincode ?? '');
    _stateCtrl = TextEditingController(text: initial?.state ?? '');
    _regionId = initial?.regionId;

    final countriesState = context.read<CountriesCubit>().state;
    if (countriesState is CountriesLoaded) {
      _prefillMobileCountry(countriesState.countries);
      if (initial != null) {
        for (final c in countriesState.countries) {
          if ((c.name ?? '').trim().toLowerCase() ==
              initial.country.trim().toLowerCase()) {
            _selectedCountry = c;
            break;
          }
        }
        if (_selectedCountry?.id != null) {
          _regionsCubit.fetchRegions(_selectedCountry!.id!);
        }
      }
    }
  }

  /// Preselects the mobile field's dial-code country — the edited address's
  /// own country code when editing, else the api's flagged default. Called
  /// once from [initState] (list may already be cached) and again from the
  /// [CountriesCubit] listener once the api response arrives.
  void _prefillMobileCountry(
    List<CountriesData> countries, {
    bool useSetState = false,
  }) {
    if (_mobileCountryPrefilled) return;
    final initialCode = widget.initial?.mobileCountryCode ?? '';
    final match = initialCode.isNotEmpty
        ? findCountryByDialCode(countries, initialCode)
        : findDefaultCountry(countries);
    if (match == null) return;
    void apply() {
      _mobileCountryPrefilled = true;
      _selectedMobileCountry = match;
    }

    if (useSetState) {
      setState(apply);
    } else {
      apply();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _pincodeCtrl.dispose();
    _stateCtrl.dispose();
    _regionsCubit.close();
    super.dispose();
  }

  void _onCountrySelected(CountriesData country) {
    final changed = _selectedCountry?.id != country.id;
    setState(() {
      _selectedCountry = country;
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

  /// Auto-selects the region matching the initial [_regionId] once the
  /// regions for the selected country load — only attempted once per country
  /// so a deliberate user pick is never overwritten by a later rebuild.
  void _onRegionsChanged(RegionsState state) {
    if (state is! RegionsLoaded || _regionAutoMatchAttempted) return;
    _regionAutoMatchAttempted = true;
    final targetId = _regionId;
    if (targetId == null) return;
    RegionsData? match;
    for (final r in state.regions) {
      if (r.id == targetId) {
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

  void _onMobileCountryChanged(CountriesData country) {
    setState(() => _selectedMobileCountry = country);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      BillingAddressData(
        name: _nameCtrl.text.trim(),
        mobile: _mobileCtrl.text.trim(),
        mobileCountryCode: formatDialCode(_selectedMobileCountry?.dialCode),
        address: _addressCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        pincode: _pincodeCtrl.text.trim(),
        country: _selectedCountry?.name ?? '',
        state: _stateCtrl.text.trim(),
        regionId: _regionId,
      ),
    );
  }

  String? _requiredValidator(String? v) => (v == null || v.trim().isEmpty)
      ? context.translate(LanguageLabelKeys.required)
      : null;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RegionsCubit>.value(
      value: _regionsCubit,
      child: BlocListener<CountriesCubit, CountriesState>(
        listener: (context, state) {
          if (state is CountriesLoaded) {
            _prefillMobileCountry(state.countries, useSetState: true);
          }
        },
        child: BlocListener<RegionsCubit, RegionsState>(
          listener: (context, state) => _onRegionsChanged(state),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: .start,
                mainAxisSize: .min,
                spacing: ThemeConstants.spaceL,
                children: [
                  AppTextField(
                    controller: _nameCtrl,
                    isRequired: true,
                    labelText: context.translate(LanguageLabelKeys.name),
                    hintText: context.translate(LanguageLabelKeys.name),
                    textCapitalization: TextCapitalization.words,
                    validator: _requiredValidator,
                  ),
                  ApiCountryPhoneField(
                    controller: _mobileCtrl,
                    selectedCountry: _selectedMobileCountry,
                    isRequired: true,
                    labelText: context.translate(LanguageLabelKeys.mobile),
                    onCountryChanged: _onMobileCountryChanged,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? context.translate(LanguageLabelKeys.mobileRequired)
                        : null,
                  ),
                  AppTextField(
                    controller: _addressCtrl,
                    isRequired: true,
                    labelText: context.translate(LanguageLabelKeys.address),
                    hintText: context.translate(
                      LanguageLabelKeys.enterFullAddress,
                    ),
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    validator: _requiredValidator,
                  ),
                  Row(
                    crossAxisAlignment: .start,
                    spacing: ThemeConstants.spaceM,
                    children: [
                      Expanded(
                        child: CountryDropdownField(
                          selected: _selectedCountry,
                          labelText: context.translate(
                            LanguageLabelKeys.country,
                          ),
                          hintText: context.translate(
                            LanguageLabelKeys.enterCountry,
                          ),
                          isRequired: true,
                          onChanged: _onCountrySelected,
                          validator: _requiredValidator,
                        ),
                      ),
                      Expanded(
                        child: BlocBuilder<RegionsCubit, RegionsState>(
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
                                isRequired: true,
                                onChanged: _onRegionSelected,
                                validator: _requiredValidator,
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
                              validator: _requiredValidator,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: .start,
                    spacing: ThemeConstants.spaceM,
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _cityCtrl,
                          isRequired: true,
                          labelText: context.translate(LanguageLabelKeys.city),
                          hintText: context.translate(
                            LanguageLabelKeys.enterCity,
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator: _requiredValidator,
                        ),
                      ),
                      Expanded(
                        child: AppTextField(
                          controller: _pincodeCtrl,
                          isRequired: true,
                          labelText: context.translate(
                            LanguageLabelKeys.pincode,
                          ),
                          hintText: context.translate(
                            LanguageLabelKeys.enterPincode,
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: _requiredValidator,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.h8,
                  AppButton(
                    label: context.translate(
                      LanguageLabelKeys.saveBillingAddress,
                    ),
                    onPressed: _submit,
                    height: 50,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
