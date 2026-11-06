import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/spin_wheel_model.dart';
import '../repositories/spin_wheel_repository.dart';

sealed class SpinWheelConfigState {
  const SpinWheelConfigState();
}

final class SpinWheelConfigLoading extends SpinWheelConfigState {
  const SpinWheelConfigLoading();
}

final class SpinWheelConfigLoaded extends SpinWheelConfigState {
  final SpinWheelData data;
  const SpinWheelConfigLoaded(this.data);
}

final class SpinWheelConfigError extends SpinWheelConfigState {
  final String message;
  // True when the API's reason is `requires_login` rather than something
  // retryable (e.g. no delivery location detected) — drives which empty
  // state / CTA the dialog shows.
  final bool requiresLogin;
  const SpinWheelConfigError(this.message, {this.requiresLogin = false});
}

/// Fetches the `spin_wheel` config (campaign, segments, theme, remaining
/// spins) that drives the wheel UI — kept separate from [SpinActionCubit],
/// which only handles the spin action itself.
class SpinWheelConfigCubit extends Cubit<SpinWheelConfigState> {
  final SpinWheelRepository _repository;

  SpinWheelConfigCubit({SpinWheelRepository? repository})
    : _repository = repository ?? SpinWheelRepository(),
      super(const SpinWheelConfigLoading());

  Future<void> load() async {
    emit(const SpinWheelConfigLoading());
    try {
      final response = await _repository.getSpinWheel();
      final data = response.data;
      if (data == null || data.segments.isEmpty) {
        // The API sends a specific reason (e.g. "We could not detect your
        // delivery location", requires_login) via `data.message` when it
        // can't serve the wheel — prefer that over the generic fallback.
        final apiMessage = data?.message.trim() ?? '';
        emit(
          SpinWheelConfigError(
            apiMessage.isNotEmpty
                ? apiMessage
                : LocalizationService.instance.translate(
                    LanguageLabelKeys.somethingWentWrong,
                  ),
            requiresLogin: data?.requiresLogin ?? false,
          ),
        );
        return;
      }
      emit(SpinWheelConfigLoaded(data));
    } on ApiException catch (e) {
      emit(SpinWheelConfigError(e.message));
    } catch (_) {
      emit(
        SpinWheelConfigError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }
}
