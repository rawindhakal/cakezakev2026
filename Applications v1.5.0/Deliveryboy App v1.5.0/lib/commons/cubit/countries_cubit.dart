import 'package:deliveryboy/commons/models/countries_model.dart';
import 'package:deliveryboy/commons/repositories/countries_repository.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/localization/services/localization_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ── States ────────────────────────────────────────────────────────────────────

/// Base state for [CountriesCubit].
sealed class CountriesState {}

/// Initial state before countries are fetched.
final class CountriesInitial extends CountriesState {}

/// Emitted while the country list is being fetched.
final class CountriesLoading extends CountriesState {}

/// Emitted once the country list has loaded successfully.
final class CountriesLoaded extends CountriesState {
  final List<CountriesData> countries;
  CountriesLoaded({required this.countries});
}

/// Emitted when fetching the country list fails.
final class CountriesError extends CountriesState {
  final String message;
  CountriesError({required this.message});
}

// ── Cubit ─────────────────────────────────────────────────────────────────────

/// Fetches and holds the list of supported countries used by country pickers/phone fields.
class CountriesCubit extends Cubit<CountriesState> {
  final CountriesRepository _repository;

  CountriesCubit({CountriesRepository? repository})
    : _repository = repository ?? CountriesRepository(),
      super(CountriesInitial());

  /// Fetches the full country list from the backend.
  Future<void> fetchCountries() async {
    emit(CountriesLoading());
    try {
      final response = await _repository.getCountries();
      emit(CountriesLoaded(countries: response.data ?? []));
    } catch (e) {
      emit(
        CountriesError(
          message: LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }
}
