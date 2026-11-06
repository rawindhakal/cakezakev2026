import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/models/country_settings_model.dart';
import 'package:customer/commons/repositories/settings_repository.dart';

/// Holds the [BuyerTaxField] spec for ONE set of coordinates — checkout
/// loads it for the billed party's (shipping) address.
///
/// Deliberately separate from the app-wide [CountrySettingsCubit] (which is
/// loaded once for the session location): the tax spec follows the buyer's
/// country, so checkout re-reads it whenever the address changes. A UAE
/// address must show "TRN" even while the session sits in India.
///
/// State is `null` while loading and [BuyerTaxField.disabled] on any failure —
/// the field is optional, so an error simply hides it instead of blocking the
/// form (the server still validates whatever is sent).
class BuyerTaxFieldCubit extends Cubit<BuyerTaxField?> {
  final SettingsRepository _repository;

  BuyerTaxFieldCubit({SettingsRepository? repository})
    : _repository = repository ?? SettingsRepository(),
      super(null);

  /// Null coordinates fall back to the session location (see
  /// [SettingsRepository.getCountrySettings]).
  Future<void> load({String? latitude, String? longitude}) async {
    try {
      final settings = await _repository.getCountrySettings(
        latitude: latitude,
        longitude: longitude,
      );
      if (isClosed) return;
      emit(settings.data?.buyerTaxField ?? BuyerTaxField.disabled);
    } catch (_) {
      if (isClosed) return;
      emit(BuyerTaxField.disabled);
    }
  }
}
