import 'package:customer/commons/cubit/api_error_guard.dart';
import 'package:customer/commons/models/zones_model.dart';
import 'package:customer/features/address/repositories/address_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ── States ────────────────────────────────────────────────────────────────────

sealed class ZonesState {}

final class ZonesInitial extends ZonesState {}

final class ZonesLoading extends ZonesState {}

final class ZonesLoaded extends ZonesState {
  final List<ZonesData> zones;
  ZonesLoaded({required this.zones});
}

final class ZonesError extends ZonesState {
  final String message;
  ZonesError({required this.message});
}

// ── Cubit ─────────────────────────────────────────────────────────────────────

/// Fetches and holds the delivery zones of the currently selected country,
/// used by [CountryZoneSelector] on the location setup screens.
class ZonesCubit extends Cubit<ZonesState> with ApiErrorGuard<ZonesState> {
  final AddressRepository _repository;

  ZonesCubit({AddressRepository? repository})
    : _repository = repository ?? AddressRepository(),
      super(ZonesInitial());

  /// Country whose zones are currently loaded/loading, so a repeated request
  /// for the same country can be skipped.
  int? _countryId;

  int? get countryId => _countryId;

  /// Fetches the zones of [countryId]. Pass [force] to refetch the same country.
  Future<void> fetchZones(int countryId, {bool force = false}) async {
    if (!force && _countryId == countryId && state is! ZonesError) return;
    _countryId = countryId;
    emit(ZonesLoading());
    await guard(
      () async {
        final response = await _repository.getZones(
          countryId: countryId.toString(),
        );
        if (_countryId != countryId) {
          return; // a newer country was selected meanwhile
        }
        emit(ZonesLoaded(zones: response.data ?? []));
      },
      onError: (msg) {
        if (_countryId != countryId) return;
        emit(ZonesError(message: msg));
      },
    );
  }

  void reset() {
    _countryId = null;
    emit(ZonesInitial());
  }
}
