import 'package:deliveryboy/commons/models/zones_model.dart';
import 'package:deliveryboy/commons/repositories/countries_repository.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/localization/services/localization_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ── States ────────────────────────────────────────────────────────────────────

/// Base state for [ZonesCubit].
sealed class ZonesState {}

/// Initial state before any country has been selected.
final class ZonesInitial extends ZonesState {}

/// Emitted while the zones of a country are being fetched.
final class ZonesLoading extends ZonesState {}

/// Emitted once the zones of a country have loaded successfully.
final class ZonesLoaded extends ZonesState {
  final List<ZonesData> zones;
  ZonesLoaded({required this.zones});
}

/// Emitted when fetching the zone list fails.
final class ZonesError extends ZonesState {
  final String message;
  ZonesError({required this.message});
}

// ── Cubit ─────────────────────────────────────────────────────────────────────

/// Fetches and holds the zones of the currently selected country, used by the
/// zone picker on the registration and edit-profile screens.
class ZonesCubit extends Cubit<ZonesState> {
  final CountriesRepository _repository;

  ZonesCubit({CountriesRepository? repository})
    : _repository = repository ?? CountriesRepository(),
      super(ZonesInitial());

  /// Country whose zones are currently loaded/loading, so a repeated request
  /// for the same country can be skipped.
  String? _countryId;

  /// The country the current zone list belongs to, or null when none is loaded.
  String? get countryId => _countryId;

  /// Fetches the zones of [countryId]. Pass [force] to refetch the same country.
  Future<void> fetchZones(String countryId, {bool force = false}) async {
    if (!force && _countryId == countryId && state is! ZonesError) return;
    _countryId = countryId;
    emit(ZonesLoading());
    try {
      final response = await _repository.getZones(countryId: countryId);
      if (_countryId != countryId) {
        return; // a newer country was selected meanwhile
      }
      emit(ZonesLoaded(zones: response.data ?? []));
    } on ApiException catch (e) {
      if (_countryId != countryId) return;
      emit(ZonesError(message: e.message));
    } catch (e) {
      if (_countryId != countryId) return;
      emit(
        ZonesError(
          message: LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }

  /// Clears the loaded zones, e.g. when the selected country is reset.
  void reset() {
    _countryId = null;
    emit(ZonesInitial());
  }
}
