import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:customer/utils/uuid_generator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/spin_wheel_model.dart';
import '../repositories/spin_wheel_repository.dart';

sealed class SpinActionState {
  const SpinActionState();
}

final class SpinActionInitial extends SpinActionState {
  const SpinActionInitial();
}

final class SpinActionInProgress extends SpinActionState {
  const SpinActionInProgress();
}

final class SpinActionSuccess extends SpinActionState {
  final SpinResultData result;
  const SpinActionSuccess(this.result);
}

final class SpinActionError extends SpinActionState {
  final String message;
  const SpinActionError(this.message);
}

class SpinActionCubit extends Cubit<SpinActionState> {
  final SpinWheelRepository _repository;

  SpinActionCubit({SpinWheelRepository? repository})
    : _repository = repository ?? SpinWheelRepository(),
      super(const SpinActionInitial());

  Future<void> spin() async {
    emit(const SpinActionInProgress());

    // Reuse a still-pending token from a previous interrupted attempt
    // (timeout / connection lost / app killed mid-request) instead of a
    // fresh one each tap — the backend uses this to recognize and dedupe
    // a spin that may have already been recorded server-side. Only cleared
    // below on an actual success response.
    final settings = SettingsHiveBox.instance;
    var requestToken = settings.spinWheelPendingRequestToken;
    if (requestToken == null) {
      requestToken = generateUuidV4();
      await settings.setSpinWheelPendingRequestToken(requestToken);
    }

    try {
      final response = await _repository.spin(requestToken: requestToken);
      final result = response.data;
      if (result == null) {
        emit(
          SpinActionError(
            LocalizationService.instance.translate(
              LanguageLabelKeys.somethingWentWrong,
            ),
          ),
        );
        return;
      }
      await settings.clearSpinWheelPendingRequestToken();
      emit(SpinActionSuccess(result));
    } on ApiException catch (e) {
      // Deliberately NOT cleared — next spin() call reuses requestToken.
      emit(SpinActionError(e.message));
    } catch (_) {
      emit(
        SpinActionError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }
}
