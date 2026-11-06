import 'package:customer/core/localization/models/language_model.dart';
import 'package:customer/core/localization/repositories/language_repository.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:customer/features/auth/repositories/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/localization/language_label_key.dart';

sealed class LanguageSelectState {}

final class LanguageSelectInitial extends LanguageSelectState {}

final class LanguageSelecting extends LanguageSelectState {}

final class LanguageSelectLoaded extends LanguageSelectState {
  final LanguageJsonData language;
  LanguageSelectLoaded(this.language);
}

final class LanguageSelectError extends LanguageSelectState {
  final String message;
  LanguageSelectError(this.message);
}

class LanguageSelectCubit extends Cubit<LanguageSelectState> {
  final LanguageRepository _languageRepo;

  LanguageSelectCubit({
    LanguageRepository? languageRepository,
    AuthRepository? authRepository,
  }) : _languageRepo = languageRepository ?? LanguageRepository(),
       super(LanguageSelectInitial());

  Future<void> selectLanguage(String id) async {
    emit(LanguageSelecting());
    try {
      final lang = await _languageRepo.fetchLanguageById(id);
      await SettingsHiveBox.instance.setLanguageId(id);
      await SettingsHiveBox.instance.setLanguageType(lang.type ?? '');
      await SettingsHiveBox.instance.setLanguageCode(lang.code ?? '');

      // Cache translations so LocalizationCubit can use them without re-fetching
      if (lang.jsonData != null) {
        LocalizationService.instance.load(lang.jsonData!);
        await SettingsHiveBox.instance.saveTranslations(
          languageId: id,
          data: lang.jsonData!,
        );
      }

      emit(LanguageSelectLoaded(lang));
    } on ApiException catch (e) {
      emit(LanguageSelectError(e.message));
    } catch (_) {
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
