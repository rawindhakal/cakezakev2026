import 'dart:async';

import 'package:customer/commons/utils/location_camera_mixin.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/custom_app_bar.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';

import 'package:customer/commons/models/app_settings_model.dart';
import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/commons/widgets/app_text_field.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:customer/features/address/widgets/address_form_sheet.dart';
import 'package:customer/features/address/widgets/location_confirm_card.dart';
import 'package:customer/features/address/widgets/location_map_view.dart';
import 'package:customer/features/address/widgets/location_search_suffix.dart';
import 'package:customer/features/address/widgets/location_suggestions.dart';
import 'package:customer/features/address/cubit/address_cubit.dart';
import 'package:customer/features/address/cubit/save_address_cubit.dart';
import 'package:customer/features/address/cubit/geocoding_cubit.dart';
import 'package:customer/features/address/cubit/zone_cubit.dart';
import 'package:customer/features/address/cubit/place_autocomplete_cubit.dart';
import 'package:customer/features/address/cubit/place_details_cubit.dart';
import 'package:customer/features/address/models/address_model.dart';
import 'package:customer/features/address/models/google_places_model.dart'
    hide Text;
import 'package:customer/features/address/models/location_result.dart';

export 'package:customer/features/address/models/location_result.dart';
import 'package:customer/utils/show_app_bottom_sheet.dart';
import 'package:customer/core/constants/theme_constants.dart';

class LocationPickerScreen extends StatefulWidget {
  final AddressData? address;

  const LocationPickerScreen({super.key, this.address});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen>
    with SingleTickerProviderStateMixin, LocationCameraMixin {
  LatLng _pickedPoint = const LatLng(20.5937, 78.9629);
  bool _isGeocoding = false;
  String _locationTitle = LocalizationService.instance.translate(
    LanguageLabelKeys.searchOrTapOnMap,
  );
  String _locationSubtitle = '';
  LocationResult? _pendingResult;

  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  bool _isSearchActive = false;
  Timer? _geocodeDebounce;

  bool get _isEdit => widget.address != null;
  AppSettingsData? get _settings => SettingsHiveBox.instance.getAppSettings();
  bool get _isGoogle => _settings?.mapProvider == AppConstants.mapProvider;

  void _fetchZone(double latitude, double longitude) {
    context.read<ZoneCubit>().fetchZone(
      latitude: latitude,
      longitude: longitude,
    );
  }

  @override
  void initState() {
    super.initState();
    initLocationCamera(this, onCameraIdle: _handleCameraIdle);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Zone call on screen open using best available coordinates
      final hive = SettingsHiveBox.instance;
      final storedLat = double.tryParse(hive.userLatitude) ?? 0;
      final storedLng = double.tryParse(hive.userLongitude) ?? 0;
      if (storedLat != 0 && storedLng != 0) {
        _fetchZone(storedLat, storedLng);
      }
    });

    if (widget.address == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _useCurrentLocation(),
      );
    }

    final a = widget.address;
    if (a != null) {
      final lat = double.tryParse(a.latitude ?? '0') ?? 0;
      final lng = double.tryParse(a.longitude ?? '0') ?? 0;
      if (lat != 0 && lng != 0) {
        _pickedPoint = LatLng(lat, lng);
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _fetchZone(lat, lng),
        );
        final parts = [a.city, a.state].where((s) => (s ?? '').isNotEmpty);
        _locationTitle = parts.join(', ');
        if (_locationTitle.isEmpty) {
          _locationTitle = LocalizationService.instance.translate(
            LanguageLabelKeys.savedLocation,
          );
        }
        _locationSubtitle = a.area ?? '';
        _pendingResult = LocationResult(
          latitude: lat,
          longitude: lng,
          city: a.city ?? '',
          state: a.state ?? '',
          country: a.country ?? '',
          pincode: a.pincode ?? '',
          area: a.area ?? '',
        );
      }
    }
  }

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    disposeLocationCamera();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Map interaction ───────────────────────────────────────────────────────

  void _handleCameraIdle(LatLng point) {
    if (skipNextIdleGeocode) {
      skipNextIdleGeocode = false;
      setState(() => _pickedPoint = point);
      return;
    }
    _closeSearch();
    setState(() {
      _pickedPoint = point;
      _locationTitle = context.translate(LanguageLabelKeys.loadingAddress);
      _locationSubtitle = '';
      _isGeocoding = true;
    });
    _geocodeDebounce?.cancel();
    _geocodeDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      context.read<GeocodingCubit>().geocode(
        latitude: point.latitude.toString(),
        longitude: point.longitude.toString(),
      );
    });
  }

  // ── Search ────────────────────────────────────────────────────────────────

  void _openSearch() {
    setState(() => _isSearchActive = true);
    _searchFocus.requestFocus();
  }

  void _closeSearch() {
    _searchController.clear();
    context.read<PlaceAutocompleteCubit>().clear();
    _searchFocus.unfocus();
    setState(() => _isSearchActive = false);
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<PlaceAutocompleteCubit>().clear();
    setState(() {});
  }

  void _onSuggestionTap(Suggestions suggestion) {
    final placeId = suggestion.placePrediction?.placeId;
    if (placeId == null || placeId.isEmpty) return;
    _searchController.clear();
    context.read<PlaceAutocompleteCubit>().clear();
    _searchFocus.unfocus();
    setState(() => _isSearchActive = false);
    context.read<PlaceDetailsCubit>().fetchDetails(placeId);
  }

  // ── Current location ──────────────────────────────────────────────────────

  Future<void> _useCurrentLocation() => useCurrentLocation(
    onLocated: (point) async {
      setState(() {
        _pickedPoint = point;
        _locationTitle = context.translate(LanguageLabelKeys.loadingAddress);
        _locationSubtitle = '';
        _isGeocoding = true;
      });
      moveCamera(point, zoom: 15, isGoogle: _isGoogle);
      context.read<GeocodingCubit>().geocode(
        latitude: point.latitude.toString(),
        longitude: point.longitude.toString(),
      );
    },
  );

  // ── Confirm ───────────────────────────────────────────────────────────────

  void _onConfirm() {
    final result =
        _pendingResult ??
        LocationResult(
          latitude: _pickedPoint.latitude,
          longitude: _pickedPoint.longitude,
        );
    final addressCubit = context.read<AddressCubit>();
    showAppBottomSheet<void>(
      context,
      showDragHandle: false,
      padding: null,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: addressCubit),
          BlocProvider.value(value: context.read<SaveAddressCubit>()),
        ],
        child: AddressFormSheet(
          address: widget.address,
          locationResult: result,
          isEdit: _isEdit,
          onSuccess: () => AppNavigator.pop(context),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<GeocodingCubit, GeocodingState>(
          listener: (context, state) {
            if (state is GeocodingLoaded) {
              final r = state.result;
              _fetchZone(_pickedPoint.latitude, _pickedPoint.longitude);
              setState(() {
                _locationTitle = r.city.isNotEmpty
                    ? r.city
                    : context.translate(LanguageLabelKeys.locationSelected);
                _locationSubtitle = r.formattedAddress;
                _isGeocoding = false;
              });
              _pendingResult = LocationResult(
                latitude: _pickedPoint.latitude,
                longitude: _pickedPoint.longitude,
                city: r.city,
                state: r.state,
                country: r.country,
                pincode: r.postalCode,
                area: r.area,
                road: r.road,
                formattedAddress: r.formattedAddress,
              );
            } else if (state is GeocodingError) {
              setState(() {
                _locationTitle = context.translate(
                  LanguageLabelKeys.locationSelected,
                );
                _locationSubtitle =
                    '${_pickedPoint.latitude.toStringAsFixed(4)}, ${_pickedPoint.longitude.toStringAsFixed(4)}';
                _isGeocoding = false;
              });
              _pendingResult = LocationResult(
                latitude: _pickedPoint.latitude,
                longitude: _pickedPoint.longitude,
              );
            }
          },
        ),
        BlocListener<PlaceDetailsCubit, PlaceDetailsState>(
          listener: (context, state) {
            if (state is PlaceDetailsLoaded) {
              final d = state.details;
              _fetchZone(d.latitude, d.longitude);
              final point = LatLng(d.latitude, d.longitude);
              moveCamera(point, zoom: 15, isGoogle: _isGoogle);
              setState(() {
                _pickedPoint = point;
                _locationTitle = d.city.isNotEmpty
                    ? d.city
                    : context.translate(LanguageLabelKeys.locationSelected);
                _locationSubtitle = d.formattedAddress;
                _isGeocoding = false;
              });
              _pendingResult = LocationResult(
                latitude: d.latitude,
                longitude: d.longitude,
                city: d.city,
                state: d.state,
                country: d.country,
                pincode: d.postalCode,
                area: d.area,
                road: d.road,
                formattedAddress: d.formattedAddress,
              );
            } else if (state is PlaceDetailsError) {
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
        applyBottomInset: false,
        appBar: CustomAppBar(
          // Same two labels the form sheet's header uses, so the map step and
          // the form it leads into read as one flow.
          title: context.translate(
            _isEdit
                ? LanguageLabelKeys.editAddress
                : LanguageLabelKeys.addNewAddress,
          ),
          onBackPressed: _isSearchActive
              ? _closeSearch
              : () => AppNavigator.pop(context),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: LocationMapView(
                isGoogle: _isGoogle,
                osmController: osmMapController,
                pickedPoint: _pickedPoint,
                pulseAnimation: pulseAnim,
                onGoogleMapCreated: (controller) =>
                    onGoogleMapCreated(controller),
                onGoogleCameraMove: onGoogleCameraMove,
                onGoogleCameraIdle: onGoogleCameraIdle,
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: .min,
                children: [
                  Container(
                    color: context.cs.surface,
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      ThemeConstants.paddingL,
                      ThemeConstants.paddingS,
                      ThemeConstants.paddingL,
                      ThemeConstants.paddingM,
                    ),
                    child: AppTextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      readOnly: !_isSearchActive,
                      onTap: _isSearchActive ? null : _openSearch,
                      hintText: context.translate(
                        LanguageLabelKeys.searchLocationHint,
                      ),
                      hintStyle: context.tt.bodyMedium?.copyWith(
                        color: _isSearchActive || _pendingResult == null
                            ? context.cs.onSurfaceVariant
                            : context.cs.onSurface,
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: ThemeConstants.paddingM,
                        ),
                        child: AppSvgIcon(
                          AssetsConstants.searchIcon,
                          size: ThemeConstants.iconS,
                          color: context.cs.onSurfaceVariant,
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 0,
                        minHeight: 0,
                      ),
                      suffixIcon: _isSearchActive
                          ? LocationSearchSuffix(
                              controller: _searchController,
                              onClear: _clearSearch,
                            )
                          : AppSpacing.shrink,
                      onChanged: _isSearchActive
                          ? (v) =>
                                context.read<PlaceAutocompleteCubit>().search(v)
                          : null,
                    ),
                  ),
                  if (_isSearchActive)
                    LocationSuggestions(onTap: _onSuggestionTap),
                ],
              ),
            ),
            if (!_isSearchActive)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: BlocBuilder<ZoneCubit, ZoneState>(
                  builder: (context, zoneState) {
                    final isZoneChecking = zoneState is ZoneLoading;
                    return LocationConfirmCard(
                      title: _locationTitle,
                      subtitle: _locationSubtitle,
                      isLocating: isLocating,
                      confirmLabel: context.translate(
                        _isEdit
                            ? LanguageLabelKeys.confirmAndEditDetails
                            : LanguageLabelKeys.confirmAndAddDetails,
                      ),
                      confirmIsLoading: isZoneChecking,
                      confirmDisabled: _isGeocoding || isZoneChecking,
                      // ZoneError is a network/server failure, not a real
                      // "not serviceable" verdict (see ZoneCubit.fetchZone) —
                      // only ZoneUnavailable should trip the unavailable
                      // banner; a transient error should read as unknown,
                      // same as before the check ran.
                      isAvailable: switch (zoneState) {
                        ZoneAvailable() => true,
                        ZoneUnavailable() => false,
                        _ => null,
                      },
                      isAvailabilityChecking: isZoneChecking,
                      onConfirm: _onConfirm,
                      onCurrentLocation: _useCurrentLocation,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
