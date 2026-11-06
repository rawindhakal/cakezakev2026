import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/product_repository.dart';

sealed class NotifyMeState {
  const NotifyMeState();
}

final class NotifyMeInitial extends NotifyMeState {
  const NotifyMeInitial();
}

final class NotifyMeInProgress extends NotifyMeState {
  const NotifyMeInProgress();
}

final class NotifyMeSuccess extends NotifyMeState {
  final String message;
  const NotifyMeSuccess(this.message);
}

final class NotifyMeError extends NotifyMeState {
  final String message;
  const NotifyMeError(this.message);
}

class NotifyMeCubit extends Cubit<NotifyMeState> {
  final ProductRepository _repository;

  NotifyMeCubit({ProductRepository? repository})
    : _repository = repository ?? ProductRepository(),
      super(const NotifyMeInitial());

  Future<void> notifyMe({required String productVariantId}) async {
    emit(const NotifyMeInProgress());
    try {
      final message = await _repository.notifyMe(
        productVariantId: productVariantId,
      );
      emit(NotifyMeSuccess(message));
    } on ApiException catch (e) {
      emit(NotifyMeError(e.message));
    } catch (_) {
      emit(
        NotifyMeError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }

  Future<void> removeNotifyMe({required String productVariantId}) async {
    emit(const NotifyMeInProgress());
    try {
      final message = await _repository.removeNotifyMe(
        productVariantId: productVariantId,
      );
      emit(NotifyMeSuccess(message));
    } on ApiException catch (e) {
      emit(NotifyMeError(e.message));
    } catch (_) {
      emit(
        NotifyMeError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }
}
