import 'dart:async';

import 'package:customer/commons/cubit/api_error_guard.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/features/address/models/google_places_model.dart';
import 'package:customer/features/address/repositories/address_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class PlaceAutocompleteState {}

final class PlaceAutocompleteInitial extends PlaceAutocompleteState {}

final class PlaceAutocompleteLoading extends PlaceAutocompleteState {}

final class PlaceAutocompleteLoaded extends PlaceAutocompleteState {
  final List<Suggestions> suggestions;
  PlaceAutocompleteLoaded(this.suggestions);
}

final class PlaceAutocompleteError extends PlaceAutocompleteState {
  final String message;
  PlaceAutocompleteError(this.message);
}

class PlaceAutocompleteCubit extends Cubit<PlaceAutocompleteState>
    with ApiErrorGuard<PlaceAutocompleteState> {
  final AddressRepository _repository;
  Timer? _debounce;

  PlaceAutocompleteCubit({AddressRepository? repository})
    : _repository = repository ?? AddressRepository(),
      super(PlaceAutocompleteInitial());

  Future<void> search(String input) async {
    _debounce?.cancel();
    if (input.trim().isEmpty) {
      emit(PlaceAutocompleteLoaded([]));
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _doSearch(input.trim()),
    );
  }

  Future<void> _doSearch(String query) async {
    emit(PlaceAutocompleteLoading());
    await guard(() async {
      final cached = SettingsHiveBox.instance.getCachedPlaceAutocomplete(query);
      final response =
          cached ?? await _repository.getPlaceAutocomplete(input: query);
      if (cached == null) {
        await SettingsHiveBox.instance.cachePlaceAutocomplete(query, response);
      }
      final model = PlaceSuggestionsModel.fromJson(response);
      emit(PlaceAutocompleteLoaded(model.data?.suggestions ?? []));
    }, onError: (msg) => emit(PlaceAutocompleteError(msg)));
  }

  void clear() {
    _debounce?.cancel();
    emit(PlaceAutocompleteLoaded([]));
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
