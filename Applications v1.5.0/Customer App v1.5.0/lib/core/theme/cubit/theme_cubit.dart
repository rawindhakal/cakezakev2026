import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../local_storage/settings_hive_box.dart';

class ThemeState {
  final ThemeMode themeMode;
  const ThemeState(this.themeMode);
}

class ThemeCubit extends Cubit<ThemeState> {
  ThemeCubit() : super(ThemeState(_loadSaved()));

  static ThemeMode _loadSaved() {
    return switch (SettingsHiveBox.instance.savedThemeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  void setLight() {
    SettingsHiveBox.instance.setThemeMode('light');
    emit(const ThemeState(ThemeMode.light));
  }

  void setDark() {
    SettingsHiveBox.instance.setThemeMode('dark');
    emit(const ThemeState(ThemeMode.dark));
  }

  void setSystem() {
    SettingsHiveBox.instance.setThemeMode('system');
    emit(const ThemeState(ThemeMode.system));
  }

  void toggle() {
    if (state.themeMode == ThemeMode.dark) {
      setLight();
    } else {
      setDark();
    }
  }
}
