import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/localization/models/language_model.dart';
import 'package:deliveryboy/core/localization/repositories/language_repository.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/core/local_storage/settings_hive_box.dart';
import 'package:deliveryboy/core/localization/services/localization_service.dart';
import 'package:deliveryboy/features/auth/repositories/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Base state for [LanguageSelectCubit].
abstract class LanguageSelectState {}

/// Initial state before a language selection is made.
class LanguageSelectInitial extends LanguageSelectState {}

/// Emitted while the selected language's data is being fetched and persisted.
class LanguageSelecting extends LanguageSelectState {}

/// Emitted once the selected language has been fetched, saved, and applied.
class LanguageSelectLoaded extends LanguageSelectState {
  final LanguageJsonData language;
  LanguageSelectLoaded(this.language);
}

/// Emitted when selecting a language fails.
class LanguageSelectError extends LanguageSelectState {
  final String message;
  LanguageSelectError(this.message);
}

/// Fetches a chosen language's data, persists it locally, and caches its translations.
class LanguageSelectCubit extends Cubit<LanguageSelectState> {
  final LanguageRepository _languageRepo;

  LanguageSelectCubit({
    LanguageRepository? languageRepository,
    AuthRepository? authRepository,
  }) : _languageRepo = languageRepository ?? LanguageRepository(),
       super(LanguageSelectInitial());

  /// Fetches language [id], saves its type/code/id locally, and caches its translations.
  Future<void> selectLanguage(String id) async {
    emit(LanguageSelecting());
    try {
      final lang = await _languageRepo.fetchLanguageById(id);
      await SettingsHiveBox.instance.setLanguageId(id);
      await SettingsHiveBox.instance.setLanguageType(lang.type ?? '');
      await SettingsHiveBox.instance.setLanguageCode(lang.code ?? '');
      await SettingsHiveBox.instance.setLanguageUserSelected(true);

      // Cache translations so LocalizationCubit can use them without re-fetching
      if (lang.jsonData != null) {
        await LocalizationService.instance.load(lang.jsonData!);
        await SettingsHiveBox.instance.saveTranslations(
          languageId: id,
          data: lang.jsonData!,
        );
      }

      emit(LanguageSelectLoaded(lang));
    } on ApiException catch (e) {
      emit(LanguageSelectError(e.message));
    } catch (e) {
      emit(
        LanguageSelectError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }
}
