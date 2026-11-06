import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/features/address/repositories/address_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ── States ────────────────────────────────────────────────────────────────────

sealed class SessionZoneState {}

final class SessionZoneInitial extends SessionZoneState {}

final class SessionZoneLoading extends SessionZoneState {}

final class SessionZoneAvailable extends SessionZoneState {
  final int? zoneId;
  final List<String> channelsAvailable;
  SessionZoneAvailable({this.zoneId, required this.channelsAvailable});

  /// Channel to activate for this zone — quick wins whenever it is offered,
  /// ecommerce only when it is the sole option. Null when the reply listed
  /// neither, so the caller keeps whatever channel is already active.
  String? get activeChannel {
    if (channelsAvailable.contains(AppConstants.quick)) {
      return AppConstants.quick;
    }
    if (channelsAvailable.contains(AppConstants.ecommerce)) {
      return AppConstants.ecommerce;
    }
    return null;
  }
}

final class SessionZoneUnavailable extends SessionZoneState {
  final String message;
  SessionZoneUnavailable({required this.message});
}

final class SessionZoneError extends SessionZoneState {}

// ── Cubit ─────────────────────────────────────────────────────────────────────

/// Zone check for the session delivery location only (home app-bar location
/// and the first-run "no location" screen) — address add/edit keep using
/// `ZoneCubit`. Never writes to the session: the picker saves zone, location
/// and channel itself once the user confirms an available point.
///
/// A point is deliverable when `channels_available` lists at least one
/// channel, even on a `status: 0` reply (e.g. quick not offered there but
/// ecommerce is).
class SessionZoneCubit extends Cubit<SessionZoneState> {
  final AddressRepository _repository;

  SessionZoneCubit({AddressRepository? repository})
    : _repository = repository ?? AddressRepository(),
      super(SessionZoneInitial());

  Future<void> checkZone({
    required double latitude,
    required double longitude,
  }) async {
    emit(SessionZoneLoading());
    try {
      final response = await _repository.getZone(
        latitude: latitude.toString(),
        longitude: longitude.toString(),
      );
      final data = response['data'];
      final zoneId = data is Map ? data['id'] as int? : null;
      emit(
        SessionZoneAvailable(
          zoneId: zoneId,
          channelsAvailable: _parseChannels(response),
        ),
      );
    } on ApiException catch (e) {
      // HTTP 200 but business status:0 — still deliverable if any channel is
      // offered, otherwise the point is outside every delivery area.
      if (e.statusCode == 200) {
        final channels = _parseChannels(e.responseData);
        emit(
          channels.isNotEmpty
              ? SessionZoneAvailable(channelsAvailable: channels)
              : SessionZoneUnavailable(message: e.message),
        );
      } else {
        emit(SessionZoneError());
      }
    } catch (_) {
      emit(SessionZoneError());
    }
  }

  /// `channels_available` sits at the top level of the reply; `data` is
  /// checked too in case the backend nests it there. Unknown values are
  /// dropped.
  static List<String> _parseChannels(Map<String, dynamic>? response) {
    final data = response?['data'];
    final raw =
        response?['channels_available'] ??
        (data is Map ? data['channels_available'] : null);
    if (raw is! List) return const [];
    return raw
        .map((c) => c.toString())
        .where((c) => c == AppConstants.quick || c == AppConstants.ecommerce)
        .toList();
  }
}
