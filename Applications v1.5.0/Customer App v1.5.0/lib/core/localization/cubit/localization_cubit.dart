import 'package:customer/core/localization/repositories/language_repository.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class LocalizationState {}

final class LocalizationInitial extends LocalizationState {}

final class LocalizationLoading extends LocalizationState {}

final class LocalizationLoaded extends LocalizationState {
  final String languageId;
  LocalizationLoaded(this.languageId);
}

final class LocalizationError extends LocalizationState {
  final String message;
  LocalizationError(this.message);
}

class LocalizationCubit extends Cubit<LocalizationState> {
  final LanguageRepository _repo;

  LocalizationCubit({LanguageRepository? repo})
    : _repo = repo ?? LanguageRepository(),
      super(LocalizationInitial());

  /// Fallback chain: Hive cache → API → assets/languages/en.json
  Future<void> loadForLanguage(String languageId) async {
    if (languageId.isEmpty) {
      emit(LocalizationLoaded(languageId));
      return;
    }

    // Already loaded this session for same language
    final current = state;
    if (current is LocalizationLoaded && current.languageId == languageId) {
      return;
    }

    final cachedId = SettingsHiveBox.instance.translationsLangId;
    final cachedData = SettingsHiveBox.instance.translationsJson;

    // 1. Hive cache hit — skip network
    if (cachedId == languageId && cachedData != null) {
      LocalizationService.instance.load(cachedData);
      emit(LocalizationLoaded(languageId));
      return;
    }

    emit(LocalizationLoading());

    // 2. API fetch
    try {
      final lang = await _repo.fetchLanguageById(languageId);
      final data = lang.jsonData ?? {};
      LocalizationService.instance.load(data);
      await SettingsHiveBox.instance.saveTranslations(
        languageId: languageId,
        data: data,
      );
      emit(LocalizationLoaded(languageId));
    } on ApiException catch (e) {
      await _applyFallback(e.message, cachedData, cachedId);
    } catch (e) {
      await _applyFallback(e.toString(), cachedData, cachedId);
    }
  }

  /// Load from Hive cache without network. Falls back to assets if Hive empty.
  Future<void> loadFromCache() async {
    final cachedId = SettingsHiveBox.instance.translationsLangId;
    final cachedData = SettingsHiveBox.instance.translationsJson;
    if (cachedData != null) {
      LocalizationService.instance.load(cachedData);
      emit(LocalizationLoaded(cachedId));
    } else {
      await _loadAssetFallback('');
    }
  }

  /// Hive stale/empty → 3. assets/languages/en.json
  Future<void> _applyFallback(
    String originalError,
    Map<dynamic, dynamic>? cachedData,
    String cachedId,
  ) async {
    if (cachedData != null) {
      LocalizationService.instance.load(cachedData);
      emit(LocalizationLoaded(cachedId));
    } else {
      await _loadAssetFallback(originalError);
    }
  }

  Future<void> _loadAssetFallback(String originalError) async {
    try {
      await LocalizationService.instance.loadFromAssets();
      emit(LocalizationLoaded(''));
    } catch (_) {
      emit(LocalizationError(originalError));
    }
  }
}
