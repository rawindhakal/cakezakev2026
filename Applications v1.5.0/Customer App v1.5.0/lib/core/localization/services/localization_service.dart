import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Extends [ChangeNotifier] so an [InheritedNotifier] wrapped around the app
/// (see `main.dart`) can rebuild every widget that reads [translate] via the
/// `context.translate()` extension when the active language changes —
/// otherwise widgets outside the tree that first loaded a key never see the
/// new value until a hot reload forces every `build()` to rerun.
class LocalizationService extends ChangeNotifier {
  LocalizationService._();
  static final LocalizationService instance = LocalizationService._();

  static const _assetPath = 'assets/languages/en.json';

  /// Local en.json — always loaded first as a base, so any key missing from
  /// the server response still resolves instead of falling back to the raw key.
  Map<String, String> _assetTranslations = {};
  Map<String, String> _translations = {};

  /// Server data overlays on top of the local asset base — missing keys in
  /// the server response keep their local fallback instead of disappearing.
  void load(Map<dynamic, dynamic> data) {
    final merged = Map<String, String>.from(_assetTranslations);
    data.forEach((k, v) {
      final value = v?.toString() ?? '';
      if (value.isNotEmpty) merged[k.toString()] = value;
    });
    _translations = merged;
    notifyListeners();
  }

  Future<void> loadFromAssets() async {
    final raw = await rootBundle.loadString(_assetPath);
    final map = jsonDecode(raw) as Map<String, dynamic>;
    _assetTranslations = map.map((k, v) => MapEntry(k, v?.toString() ?? ''));
    _translations = Map.from(_assetTranslations);
    notifyListeners();
  }

  void clear() {
    _translations = {};
    notifyListeners();
  }

  bool get hasTranslations => _translations.isNotEmpty;

  String translate(String key, {String? fallback}) {
    final val = _translations[key];
    if (val != null && val.isNotEmpty) return val;
    return fallback ?? key;
  }
}

/// Wraps the app so `context.translate()` can register a rebuild dependency
/// on [LocalizationService] the same way `Directionality.of(context)` does
/// for text direction — see `main.dart`.
class LocalizationScope extends InheritedNotifier<LocalizationService> {
  const LocalizationScope({
    super.key,
    required super.notifier,
    required super.child,
  });
}
