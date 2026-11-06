import 'package:customer/commons/cubit/api_error_guard.dart';
import 'package:customer/commons/models/regions_model.dart';
import 'package:customer/features/address/repositories/address_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ── States ────────────────────────────────────────────────────────────────────

sealed class RegionsState {}

final class RegionsInitial extends RegionsState {}

final class RegionsLoading extends RegionsState {}

final class RegionsLoaded extends RegionsState {
  final List<RegionsData> regions;
  RegionsLoaded({required this.regions});
}

final class RegionsError extends RegionsState {
  final String message;
  RegionsError({required this.message});
}

// ── Cubit ─────────────────────────────────────────────────────────────────────

/// Fetches and holds the regions (states/provinces) of the currently
/// selected country.
class RegionsCubit extends Cubit<RegionsState>
    with ApiErrorGuard<RegionsState> {
  final AddressRepository _repository;

  RegionsCubit({AddressRepository? repository})
    : _repository = repository ?? AddressRepository(),
      super(RegionsInitial());

  /// Country whose regions are currently loaded/loading, so a repeated
  /// request for the same country can be skipped.
  int? _countryId;

  int? get countryId => _countryId;

  /// Fetches the regions of [countryId]. Pass [force] to refetch the same country.
  Future<void> fetchRegions(int countryId, {bool force = false}) async {
    if (!force && _countryId == countryId && state is! RegionsError) return;
    _countryId = countryId;
    emit(RegionsLoading());
    await guard(
      () async {
        final response = await _repository.getRegions(
          countryId: countryId.toString(),
        );
        if (_countryId != countryId) {
          return; // a newer country was selected meanwhile
        }
        emit(RegionsLoaded(regions: response.data ?? []));
      },
      onError: (msg) {
        if (_countryId != countryId) return;
        emit(RegionsError(message: msg));
      },
    );
  }

  void reset() {
    _countryId = null;
    emit(RegionsInitial());
  }
}
