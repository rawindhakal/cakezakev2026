import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/features/address/models/google_places_model.dart';
import 'package:customer/features/address/repositories/address_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:customer/core/localization/language_label_key.dart';

// ── States ─────────────────────────────────────────────────────────────────

sealed class UserLocationState {}

final class UserLocationInitial extends UserLocationState {}

final class UserLocationDetecting extends UserLocationState {}

final class UserLocationDetected extends UserLocationState {
  final double latitude;
  final double longitude;
  final String label;
  final String address;

  UserLocationDetected({
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.address,
  });
}

final class UserLocationPermissionDenied extends UserLocationState {
  final bool permanent;
  UserLocationPermissionDenied({this.permanent = false});
}

final class UserLocationError extends UserLocationState {
  final String message;
  UserLocationError(this.message);
}

// ── Cubit ──────────────────────────────────────────────────────────────────

class UserLocationCubit extends Cubit<UserLocationState> {
  final AddressRepository _repository;

  UserLocationCubit({AddressRepository? repository})
    : _repository = repository ?? AddressRepository(),
      super(UserLocationInitial());

  Future<void> detectCurrentLocation() async {
    emit(UserLocationDetecting());
    try {
      // 1. Check if service is enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        emit(
          UserLocationError(
            LocalizationService.instance.translate(
              LanguageLabelKeys.locationServicesDisabled,
            ),
          ),
        );
        return;
      }

      // 2. Check / request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          emit(UserLocationPermissionDenied());
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        emit(UserLocationPermissionDenied(permanent: true));
        return;
      }

      // 3. Get GPS position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // 4. Reverse geocode via API
      final response = await _repository.getGeocodingByLatLng(
        latitude: position.latitude.toString(),
        longitude: position.longitude.toString(),
      );
      final result = GeocodingResult.fromJson(response);

      // 5. Build short label (city or first part of formatted address)
      final label = result.city.isNotEmpty
          ? result.city
          : result.formattedAddress.split(',').first.trim();

      // 6. Persist to hive
      await SettingsHiveBox.instance.saveUserLocation(
        latitude: position.latitude.toString(),
        longitude: position.longitude.toString(),
        label: label,
        address: result.formattedAddress,
        pincode: result.postalCode,
      );

      emit(
        UserLocationDetected(
          latitude: position.latitude,
          longitude: position.longitude,
          label: label,
          address: result.formattedAddress,
        ),
      );
    } on ApiException catch (e) {
      emit(UserLocationError(e.message));
    } catch (_) {
      emit(
        UserLocationError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }

  void reset() => emit(UserLocationInitial());
}
