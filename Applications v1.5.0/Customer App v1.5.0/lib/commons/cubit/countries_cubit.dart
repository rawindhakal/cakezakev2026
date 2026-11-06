import 'package:customer/commons/cubit/api_error_guard.dart';
import 'package:customer/commons/models/countries_model.dart';
import 'package:customer/features/address/repositories/address_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ── States ────────────────────────────────────────────────────────────────────

sealed class CountriesState {}

final class CountriesInitial extends CountriesState {}

final class CountriesLoading extends CountriesState {}

final class CountriesLoaded extends CountriesState {
  final List<CountriesData> countries;
  CountriesLoaded({required this.countries});
}

final class CountriesError extends CountriesState {
  final String message;
  CountriesError({required this.message});
}

// ── Cubit ─────────────────────────────────────────────────────────────────────

class CountriesCubit extends Cubit<CountriesState>
    with ApiErrorGuard<CountriesState> {
  final AddressRepository _repository;

  CountriesCubit({AddressRepository? repository})
    : _repository = repository ?? AddressRepository(),
      super(CountriesInitial());

  Future<void> fetchCountries() async {
    emit(CountriesLoading());
    await guard(() async {
      final response = await _repository.getCountries();
      emit(CountriesLoaded(countries: response.data ?? []));
    }, onError: (msg) => emit(CountriesError(message: msg)));
  }
}
