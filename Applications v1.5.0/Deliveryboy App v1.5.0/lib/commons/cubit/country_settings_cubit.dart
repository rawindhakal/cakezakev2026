import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/localization/services/localization_service.dart';
import 'package:deliveryboy/core/local_storage/settings_hive_box.dart';
import 'package:deliveryboy/commons/repositories/settings_repository.dart';
import 'package:deliveryboy/commons/models/country_settings_model.dart';

/// Base state for [CountrySettingsCubit].
sealed class CountrySettingsState {}

/// Initial state before country settings are fetched.
final class CountrySettingsInitial extends CountrySettingsState {}

/// Emitted while country settings are being fetched.
final class CountrySettingsLoading extends CountrySettingsState {}

/// Emitted once country settings have loaded successfully.
final class CountrySettingsLoaded extends CountrySettingsState {
  final CountrySettings settings;
  CountrySettingsLoaded(this.settings);
}

/// Emitted when fetching country settings fails.
final class CountrySettingsError extends CountrySettingsState {
  final String message;
  CountrySettingsError(this.message);
}

/// Fetches and caches per-country settings (currency, date/time format) for the current user.
class CountrySettingsCubit extends Cubit<CountrySettingsState> {
  final SettingsRepository _repository;

  CountrySettingsCubit({SettingsRepository? repository})
    : _repository = repository ?? SettingsRepository(),
      super(CountrySettingsInitial());

  /// Returns the loaded currency symbol, or an empty string if not yet loaded.
  String getCurrencySymbol() {
    final state = this.state;
    if (state is! CountrySettingsLoaded) return '';
    return state.settings.data?.currency ?? '';
  }

  /// Fetches country settings, skipping the call if already loaded/loading unless [force] is true.
  Future<void> loadCountrySettings({bool force = false}) async {
    if (!force && state is CountrySettingsLoaded) return;
    if (!force && state is CountrySettingsLoading) return;
    emit(CountrySettingsLoading());
    try {
      final settings = await _repository.getCountrySettings();
      await SettingsHiveBox.instance.saveDateTimeFormat(
        dateFormat: settings.data?.dateFormat,
        timeFormat: settings.data?.timeFormat,
      );
      emit(CountrySettingsLoaded(settings));
    } on ApiException catch (e) {
      emit(CountrySettingsError(e.message));
    } catch (e) {
      emit(
        CountrySettingsError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }
}
