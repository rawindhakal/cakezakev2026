import 'package:customer/commons/models/app_settings_model.dart';
import 'package:customer/core/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/commons/repositories/settings_repository.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:customer/core/localization/language_label_key.dart';

// ── States ──────────────────────────────────────────────────────────────────
sealed class SettingsState {}

final class SettingsInitial extends SettingsState {}

final class SettingsLoading extends SettingsState {}

final class SettingsLoaded extends SettingsState {
  final AppSettings settings;
  SettingsLoaded(this.settings);
}

final class SettingsError extends SettingsState {
  final String message;
  SettingsError(this.message);
}

// ── Cubit ────────────────────────────────────────────────────────────────────
class SettingsCubit extends Cubit<SettingsState> {
  final SettingsRepository _repository;

  SettingsCubit({SettingsRepository? repository})
    : _repository = repository ?? SettingsRepository(),
      super(_initialState());

  /// Seeds state from the Hive cache (saved last session) so the first
  /// frame — splash background color included — reflects it immediately,
  /// instead of the hardcoded fallback while the settings API is in flight.
  static SettingsState _initialState() {
    final cached = SettingsHiveBox.instance.getAppSettings();
    return cached != null
        ? SettingsLoaded(AppSettings(data: cached))
        : SettingsInitial();
  }

  Future<void> loadSettings() async {
    // Skip blanking out already-loaded (cached) data with SettingsLoading —
    // that transient null state can flash the fallback color/UI if some
    // unrelated rebuild lands mid-fetch. Only show Loading from a cold start.
    if (state is! SettingsLoaded) emit(SettingsLoading());
    const maxAttempts = 2;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final settings = await _repository.getSettings();
        // Save to Hive for offline access
        await SettingsHiveBox.instance.saveAppSettings(settings.data!);
        emit(SettingsLoaded(settings));
        return;
      } on ApiException catch (e) {
        if (attempt < maxAttempts) {
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }
        _emitFallback(e.message);
      } catch (_) {
        if (attempt < maxAttempts) {
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }
        _emitFallback(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        );
      }
    }
  }

  // Try to load from cache if API fails after all retry attempts.
  void _emitFallback(String errorMessage) {
    final cached = SettingsHiveBox.instance.getAppSettings();
    if (cached != null) {
      emit(SettingsLoaded(AppSettings(data: cached)));
    } else {
      emit(SettingsError(errorMessage));
    }
  }

  /// Returns the light-theme primary color from Settings API, falling back to AppColors.primary.
  Color getLightPrimaryColor() {
    final data = (state is SettingsLoaded)
        ? (state as SettingsLoaded).settings.data
        : null;
    return parseHexColor(data?.customerLightModeColor);
  }

  /// Returns the dark-theme primary color from Settings API, falling back to AppColors.primary.
  Color getDarkPrimaryColor() {
    final data = (state is SettingsLoaded)
        ? (state as SettingsLoaded).settings.data
        : null;
    return parseHexColor(data?.customerDarkModeColor);
  }
}
