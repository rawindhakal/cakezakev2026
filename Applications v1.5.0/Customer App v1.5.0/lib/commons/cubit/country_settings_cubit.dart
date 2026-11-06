import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/commons/repositories/settings_repository.dart';
import 'package:customer/commons/models/country_settings_model.dart';

sealed class CountrySettingsState {}

final class CountrySettingsInitial extends CountrySettingsState {}

final class CountrySettingsLoading extends CountrySettingsState {}

final class CountrySettingsLoaded extends CountrySettingsState {
  final CountrySettings settings;
  CountrySettingsLoaded(this.settings);
}

final class CountrySettingsError extends CountrySettingsState {
  final String message;
  CountrySettingsError(this.message);
}

class CountrySettingsCubit extends Cubit<CountrySettingsState> {
  final SettingsRepository _repository;

  CountrySettingsCubit({SettingsRepository? repository})
    : _repository = repository ?? SettingsRepository(),
      super(CountrySettingsInitial());

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
      emit(CountrySettingsError(e.toString()));
    }
  }

  String getCurrencySymbol() {
    final current = state;
    if (current is! CountrySettingsLoaded) return '';
    return current.settings.data?.currency ?? '';
  }

  int getDecimalPoint() {
    final current = state;
    if (current is! CountrySettingsLoaded) return 2;
    return current.settings.data?.decimalPoint ?? 2;
  }
}
