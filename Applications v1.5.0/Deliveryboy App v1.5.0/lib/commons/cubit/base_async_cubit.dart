import 'package:deliveryboy/core/api/api_exception.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/localization/services/localization_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ── States ────────────────────────────────────────────────────────────────────
/// Base state for [BaseAsyncCubit].
sealed class AsyncState<T> {
  const AsyncState();
}

/// Initial state before the first load.
final class AsyncInitial<T> extends AsyncState<T> {
  const AsyncInitial();
}

/// Emitted while an async call is in flight.
final class AsyncLoading<T> extends AsyncState<T> {
  const AsyncLoading();
}

/// Emitted once the async call has completed successfully.
final class AsyncLoaded<T> extends AsyncState<T> {
  final T data;
  const AsyncLoaded(this.data);
}

/// Emitted when the async call fails.
final class AsyncError<T> extends AsyncState<T> {
  final String message;
  const AsyncError(this.message);
}

// ── Base Cubit ────────────────────────────────────────────────────────────────
/// Generic single-shot async cubit: emits Loading, then Loaded/Error, around
/// one API call. Replaces the repeated `on ApiException catch (e) { emit(XError) }`
/// boilerplate that every feature cubit used to hand-write.
abstract class BaseAsyncCubit<T> extends Cubit<AsyncState<T>> {
  BaseAsyncCubit() : super(AsyncInitial<T>());

  /// Runs [action], emitting [AsyncLoading] first, then [AsyncLoaded] with its
  /// result, or [AsyncError] with the API's message (or a localized generic
  /// message for non-API errors). [onUnexpectedError] is an optional hook
  /// (e.g. Crashlytics logging) invoked before the error state for non-API
  /// errors. [onSuccess] runs after the successful result is computed but
  /// before it's emitted, for side effects (analytics, persistence) that need
  /// to happen exactly once per successful call.
  Future<void> run(
    Future<T> Function() action, {
    void Function(T result)? onSuccess,
    void Function(Object error, StackTrace stackTrace)? onUnexpectedError,
  }) async {
    emit(AsyncLoading<T>());
    try {
      final result = await action();
      // Side-effect failures (analytics/crashlytics/etc.) must never mask a
      // successful result as an error.
      try {
        onSuccess?.call(result);
      } catch (_) {}
      emit(AsyncLoaded<T>(result));
    } on ApiException catch (e) {
      emit(AsyncError<T>(e.message));
    } catch (e, stack) {
      onUnexpectedError?.call(e, stack);
      emit(
        AsyncError<T>(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }
}
