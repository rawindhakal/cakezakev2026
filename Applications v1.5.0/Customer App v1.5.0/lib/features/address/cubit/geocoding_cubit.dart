import 'package:customer/commons/cubit/api_error_guard.dart';
import 'package:customer/features/address/models/google_places_model.dart';
import 'package:customer/features/address/repositories/address_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class GeocodingState {}

final class GeocodingInitial extends GeocodingState {}

final class GeocodingLoading extends GeocodingState {}

final class GeocodingLoaded extends GeocodingState {
  final GeocodingResult result;
  GeocodingLoaded(this.result);
}

final class GeocodingError extends GeocodingState {
  final String message;
  GeocodingError(this.message);
}

class GeocodingCubit extends Cubit<GeocodingState>
    with ApiErrorGuard<GeocodingState> {
  final AddressRepository _repository;

  GeocodingCubit({AddressRepository? repository})
    : _repository = repository ?? AddressRepository(),
      super(GeocodingInitial());

  Future<void> geocode({
    required String latitude,
    required String longitude,
    String? channel,
  }) async {
    emit(GeocodingLoading());
    await guard(() async {
      final response = await _repository.getGeocodingByLatLng(
        latitude: latitude,
        longitude: longitude,
        channel: channel,
      );
      emit(GeocodingLoaded(GeocodingResult.fromJson(response)));
    }, onError: (msg) => emit(GeocodingError(msg)));
  }

  void reset() => emit(GeocodingInitial());
}
