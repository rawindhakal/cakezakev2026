import 'dart:io';

import 'package:deliveryboy/commons/models/app_settings_model.dart';
import 'package:deliveryboy/core/constants/app_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/localization/services/localization_service.dart';
import 'package:deliveryboy/core/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/core/local_storage/settings_hive_box.dart';
import 'package:deliveryboy/commons/repositories/settings_repository.dart';

// ── States ──────────────────────────────────────────────────────────────────
/// Base state for [SettingsCubit].
abstract class SettingsState {}

/// Initial state before app settings are loaded (unless a Hive cache pre-seeds [SettingsLoaded]).
class SettingsInitial extends SettingsState {}

/// Emitted while app settings are being fetched from a cold start.
class SettingsLoading extends SettingsState {}

/// Emitted once app settings are available, from network or cache.
class SettingsLoaded extends SettingsState {
  final AppSettings settings;
  SettingsLoaded(this.settings);
}

/// Emitted when fetching app settings fails and no cache is available.
class SettingsError extends SettingsState {
  final String message;
  SettingsError(this.message);
}

// ── Cubit ────────────────────────────────────────────────────────────────────
/// Fetches, caches, and exposes app-wide settings (theme colors, store URLs, map provider).
class SettingsCubit extends Cubit<SettingsState> {
  final SettingsRepository _repository;

  SettingsCubit({SettingsRepository? repository})
    : _repository = repository ?? SettingsRepository(),
      super(_cachedState());

  static SettingsState _cachedState() {
    final cached = SettingsHiveBox.instance.getAppSettings();
    if (cached != null) return SettingsLoaded(AppSettings(data: cached));
    return SettingsInitial();
  }

  /// Fetches app settings from the API, caching them to Hive, and falls back to cache on failure.
  Future<void> loadSettings() async {
    // Skip blanking out already-loaded (cached) data with SettingsLoading —
    // that transient null state can flash the fallback color/UI if some
    // unrelated rebuild lands mid-fetch. Only show Loading from a cold start.
    if (state is! SettingsLoaded) emit(SettingsLoading());
    try {
      final settings = await _repository.getSettings();
      // Save to Hive for offline access
      await SettingsHiveBox.instance.saveAppSettings(settings.data!);
      emit(SettingsLoaded(settings));
    } on ApiException catch (e) {
      // Try to load from cache if API fails
      final cached = SettingsHiveBox.instance.getAppSettings();
      if (cached != null) {
        emit(SettingsLoaded(AppSettings(data: cached)));
      } else {
        emit(SettingsError(e.message));
      }
    } catch (e) {
      // Try to load from cache if API fails
      final cached = SettingsHiveBox.instance.getAppSettings();
      if (cached != null) {
        emit(SettingsLoaded(AppSettings(data: cached)));
      } else {
        emit(
          SettingsError(
            LocalizationService.instance.translate(
              LanguageLabelKeys.somethingWentWrong,
            ),
          ),
        );
      }
    }
  }

  Color getLightPrimaryColor() {
    final data = (state is SettingsLoaded)
        ? (state as SettingsLoaded).settings.data
        : null;
    return parseHexColor(data?.deliveryBoyLightModeColor);
  }

  Color getDarkPrimaryColor() {
    final data = (state is SettingsLoaded)
        ? (state as SettingsLoaded).settings.data
        : null;
    return parseHexColor(data?.deliveryBoyDarkModeColor);
  }

  String? getAppUrl() {
    final settings = (state is SettingsLoaded)
        ? (state as SettingsLoaded).settings
        : null;
    if (settings == null) return '';
    // Assuming settings.data contains a map of currency codes to symbols
    return Platform.isAndroid
        ? settings.data?.deliveryBoyPlaystoreUrl
        : settings.data?.deliveryBoyAppstoreUrl;
  }

  bool isGoogleMapProvider() {
    final data = (state is SettingsLoaded)
        ? (state as SettingsLoaded).settings.data
        : null;
    return data?.mapProvider == AppConstants.mapProviderGoogle;
  }
}
