import 'package:customer/core/configs/app_config.dart';
import 'package:customer/core/localization/cubit/language_cubit.dart';
import 'package:customer/core/localization/models/language_model.dart';
import 'package:flutter/material.dart';

(TextDirection, Locale) resolveLocale(LanguageState langState) {
  if (langState is LanguageLoaded && langState.languages.isNotEmpty) {
    final selected = langState.languages.firstWhere(
      (l) => l.id == langState.selectedId,
      orElse: () => LanguageJsonData(),
    );
    final isRtl = (selected.type ?? '').toLowerCase() == 'rtl';
    final parts = (selected.code ?? AppConfig.defaultLanguageCode).split('_');
    final locale = parts.length >= 2
        ? Locale(parts[0], parts[1])
        : Locale(parts[0]);
    return (isRtl ? TextDirection.rtl : TextDirection.ltr, locale);
  }
  return (TextDirection.ltr, const Locale(AppConfig.defaultLanguageCode));
}
