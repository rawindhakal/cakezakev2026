import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/localization/models/language_model.dart';
import 'package:deliveryboy/core/localization/repositories/language_repository.dart';
import 'package:deliveryboy/core/localization/services/localization_service.dart';
import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/core/local_storage/settings_hive_box.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Base state for [LanguageCubit].
abstract class LanguageState {}

/// Initial state before languages are loaded.
class LanguageInitial extends LanguageState {}

/// Emitted while the language list is being fetched.
class LanguageLoading extends LanguageState {}

/// Emitted once the language list has loaded successfully.
class LanguageLoaded extends LanguageState {
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

/// Emitted when loading the language list fails.
class LanguageError extends LanguageState {
  final String message;
  LanguageError(this.message);
}

/// Loads the available system languages and tracks the currently-selected one.
class LanguageCubit extends Cubit<LanguageState> {
  final LanguageRepository _languageRepo;

  LanguageCubit({LanguageRepository? languageRepository})
    : _languageRepo = languageRepository ?? LanguageRepository(),
      super(LanguageInitial());

  /// Fetches the system language list and selects the saved or default language.
  Future<void> loadLanguages() async {
    emit(LanguageLoading());
    try {
      final languages = await _languageRepo.fetchLanguages();
      final savedId = SettingsHiveBox.instance.languageId;
      final userSelected = SettingsHiveBox.instance.languageUserSelected;

      // Only honour the saved ID when the user picked it by hand, and only
      // while it still exists in the list — a language removed from the admin
      // panel (or a saved ID from a different backend) would otherwise select
      // nothing and leave the list showing no selection. An auto-picked ID
      // (never chosen by the user) keeps following the backend's `is_default`
      // flag instead, so flipping the default on the backend takes effect.
      final saved = userSelected
          ? languages.where((l) => l.id != null && l.id == savedId).firstOrNull
          : null;
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
    } catch (e) {
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

  /// Updates the currently-selected language ID without refetching.
  void updateSelectedId(String id) {
    final current = state;
    if (current is LanguageLoaded) {
      emit(current.copyWith(selectedId: id));
    }
  }
}
