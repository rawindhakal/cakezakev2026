import 'package:customer/core/localization/models/language_model.dart';
import 'package:customer/core/localization/repositories/language_repository.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:customer/core/localization/language_label_key.dart';

sealed class LanguageState {}

final class LanguageInitial extends LanguageState {}

final class LanguageLoading extends LanguageState {}

final class LanguageLoaded extends LanguageState {
  final List<LanguageJsonData> languages;
  final String? selectedId;

  LanguageLoaded({required this.languages, this.selectedId});

  LanguageLoaded copyWith({
    List<LanguageJsonData>? languages,
    String? selectedId,
  }) {
    return LanguageLoaded(
      languages: languages ?? this.languages,
      selectedId: selectedId ?? this.selectedId,
    );
  }
}

final class LanguageError extends LanguageState {
  final String message;
  LanguageError(this.message);
}

class LanguageCubit extends Cubit<LanguageState> {
  final LanguageRepository _languageRepo;

  LanguageCubit({LanguageRepository? languageRepository})
    : _languageRepo = languageRepository ?? LanguageRepository(),
      super(LanguageInitial());

  Future<void> loadLanguages() async {
    emit(LanguageLoading());
    try {
      final languages = await _languageRepo.fetchLanguages();
      final savedId = SettingsHiveBox.instance.languageId;

      // Only honour the saved ID while it still exists in the list — a language
      // removed from the admin panel (or a saved ID from a different backend)
      // would otherwise select nothing and leave the list showing no selection.
      final saved = languages
          .where((l) => l.id != null && l.id == savedId)
          .firstOrNull;
      final selected =
          saved ??
          languages.where((l) => _isDefault(l)).firstOrNull ??
          (languages.isNotEmpty ? languages.first : null);
      final selectedId = selected?.id ?? '';

      // Persist the resolved language on first launch too. Without this the
      // Hive values stay empty until the user changes the language by hand, so
      // the Content-Language header, the login payload and the profile tile's
      // fallback all keep using the hardcoded default instead of the backend's.
      if (selected != null && savedId != selectedId) {
        await SettingsHiveBox.instance.setLanguageId(selectedId);
        await SettingsHiveBox.instance.setLanguageCode(selected.code ?? '');
        await SettingsHiveBox.instance.setLanguageType(selected.type ?? '');
      }

      emit(LanguageLoaded(languages: languages, selectedId: selectedId));
    } on ApiException catch (e) {
      emit(LanguageError(e.message));
    } catch (_) {
      emit(
        LanguageError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }

  /// Whether [lang] is the backend's default language. The flag arrives as a
  /// stringified `1`/`0` today, but tolerate `true`/`yes` so a backend change
  /// can't silently drop the app back to the first language in the list.
  static bool _isDefault(LanguageJsonData lang) {
    final flag = (lang.isDefault ?? '').trim().toLowerCase();
    return flag == '1' || flag == 'true' || flag == 'yes';
  }

  void updateSelectedId(String id) {
    final current = state;
    if (current is LanguageLoaded) {
      emit(current.copyWith(selectedId: id));
    }
  }
}
