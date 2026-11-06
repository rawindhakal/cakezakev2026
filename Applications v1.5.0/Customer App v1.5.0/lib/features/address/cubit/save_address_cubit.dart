import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/address_model.dart';
import '../repositories/address_repository.dart';
import 'package:customer/commons/cubit/api_error_guard.dart';

sealed class SaveAddressState {}

final class SaveAddressInitial extends SaveAddressState {}

final class SaveAddressLoading extends SaveAddressState {}

final class SaveAddressSuccess extends SaveAddressState {
  /// Saved address from the response (null if the API didn't return it).
  final AddressData? address;
  final bool isEdit;
  SaveAddressSuccess({this.address, required this.isEdit});
}

final class SaveAddressError extends SaveAddressState {
  final String message;
  SaveAddressError(this.message);
}

class SaveAddressCubit extends Cubit<SaveAddressState>
    with ApiErrorGuard<SaveAddressState> {
  final AddressRepository _repository;

  SaveAddressCubit({AddressRepository? repository})
    : _repository = repository ?? AddressRepository(),
      super(SaveAddressInitial());

  Future<void> addAddress({
    required String name,
    required String mobile,
    String? countryCode,
    String? alternateMobile,
    String? alternateCountryCode,
    required String address,
    String? landmark,
    String? area,
    required String pincode,
    required String city,
    required String state,
    required String country,
    required String type,
    String latitude = '0',
    String longitude = '0',
    bool isDefault = false,
    int? regionId,
  }) async {
    emit(SaveAddressLoading());
    await guard(() async {
      final saved = await _repository.saveAddress(
        AddressData(
          name: name,
          mobile: mobile,
          countryCode: countryCode,
          alternateMobile: alternateMobile,
          alternateCountryCode: alternateCountryCode,
          address: address,
          landmark: landmark,
          area: area,
          pincode: pincode,
          city: city,
          state: state,
          country: country,
          type: type,
          latitude: latitude,
          longitude: longitude,
          isDefault: isDefault ? '1' : '0',
          regionId: regionId,
        ),
      );
      emit(SaveAddressSuccess(address: saved, isEdit: false));
    }, onError: (msg) => emit(SaveAddressError(msg)));
  }

  Future<void> updateAddress({
    required String id,
    required String name,
    required String mobile,
    String? countryCode,
    String? alternateMobile,
    String? alternateCountryCode,
    required String address,
    String? landmark,
    String? area,
    required String pincode,
    required String city,
    required String state,
    required String country,
    required String type,
    String latitude = '0',
    String longitude = '0',
    bool isDefault = false,
    int? regionId,
  }) async {
    emit(SaveAddressLoading());
    await guard(() async {
      final saved = await _repository.saveAddress(
        AddressData(
          id: id,
          name: name,
          mobile: mobile,
          countryCode: countryCode,
          alternateMobile: alternateMobile,
          alternateCountryCode: alternateCountryCode,
          address: address,
          landmark: landmark,
          area: area,
          pincode: pincode,
          city: city,
          state: state,
          country: country,
          type: type,
          latitude: latitude,
          longitude: longitude,
          isDefault: isDefault ? '1' : '0',
          regionId: regionId,
        ),
        isEdit: true,
      );
      emit(SaveAddressSuccess(address: saved, isEdit: true));
    }, onError: (msg) => emit(SaveAddressError(msg)));
  }
}
