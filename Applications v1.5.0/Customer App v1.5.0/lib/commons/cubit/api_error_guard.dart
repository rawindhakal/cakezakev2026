import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Extracts the repeated `on ApiException catch (e) { ... } catch (_) { ... }`
/// scaffolding shared by simple fetch cubits. Leaves each cubit's own state
/// classes untouched — only wraps the try/catch.
mixin ApiErrorGuard<S> on Cubit<S> {
  Future<void> guard(
    Future<void> Function() action, {
    required void Function(String message) onError,
  }) async {
    try {
      await action();
    } on ApiException catch (e) {
      onError(e.message);
    } catch (_) {
      onError(
        LocalizationService.instance.translate(
          LanguageLabelKeys.somethingWentWrong,
        ),
      );
    }
  }
}
