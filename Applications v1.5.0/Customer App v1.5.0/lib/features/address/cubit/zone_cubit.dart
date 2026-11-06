import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/features/address/repositories/address_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ── States ────────────────────────────────────────────────────────────────────

sealed class ZoneState {}

final class ZoneInitial extends ZoneState {}

final class ZoneLoading extends ZoneState {}

final class ZoneAvailable extends ZoneState {
  final int? zoneId;
  ZoneAvailable({this.zoneId});
}

final class ZoneUnavailable extends ZoneState {
  final String message;
  ZoneUnavailable({required this.message});
}

final class ZoneError extends ZoneState {}

// ── Cubit ─────────────────────────────────────────────────────────────────────

class ZoneCubit extends Cubit<ZoneState> {
  final AddressRepository _repository;

  ZoneCubit({AddressRepository? repository})
    : _repository = repository ?? AddressRepository(),
      super(ZoneInitial());

  Future<void> fetchZone({
    required double latitude,
    required double longitude,
  }) async {
    emit(ZoneLoading());
    try {
      final response = await _repository.getZone(
        latitude: latitude.toString(),
        longitude: longitude.toString(),
      );
      final zoneId = response['data']?['id'] as int?;
      await SettingsHiveBox.instance.saveZoneId(zoneId);
      emit(ZoneAvailable(zoneId: zoneId));
    } on ApiException catch (e) {
      // HTTP 200 but business status:0 → zone not serviceable at this location
      if (e.statusCode == 200) {
        emit(ZoneUnavailable(message: e.message));
      } else {
        // Network/server error — don't block user, silently reset
        emit(ZoneError());
      }
    } catch (_) {
      emit(ZoneError());
    }
  }

  void reset() => emit(ZoneInitial());
}
