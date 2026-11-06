import 'package:customer/commons/cubit/api_error_guard.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/features/address/models/google_places_model.dart';
import 'package:customer/features/address/repositories/address_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class PlaceDetailsState {}

final class PlaceDetailsInitial extends PlaceDetailsState {}

final class PlaceDetailsLoading extends PlaceDetailsState {}

final class PlaceDetailsLoaded extends PlaceDetailsState {
  final PlaceDetails details;
  PlaceDetailsLoaded(this.details);
}

final class PlaceDetailsError extends PlaceDetailsState {
  final String message;
  PlaceDetailsError(this.message);
}

class PlaceDetailsCubit extends Cubit<PlaceDetailsState>
    with ApiErrorGuard<PlaceDetailsState> {
  final AddressRepository _repository;

  PlaceDetailsCubit({AddressRepository? repository})
    : _repository = repository ?? AddressRepository(),
      super(PlaceDetailsInitial());

  Future<void> fetchDetails(String placeId) async {
    emit(PlaceDetailsLoading());
    await guard(() async {
      final cached = SettingsHiveBox.instance.getCachedPlaceDetails(placeId);
      final response =
          cached ?? await _repository.getPlaceDetails(placeId: placeId);
      if (cached == null) {
        await SettingsHiveBox.instance.cachePlaceDetails(placeId, response);
      }
      emit(PlaceDetailsLoaded(PlaceDetails.fromJson(response)));
    }, onError: (msg) => emit(PlaceDetailsError(msg)));
  }

  void reset() => emit(PlaceDetailsInitial());
}
