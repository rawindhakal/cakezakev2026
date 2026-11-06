import '../../../commons/cubit/base_async_cubit.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/crashlytics_service.dart';
import '../repositories/wallet_repository.dart';

// ── States ──────────────────────────────────────────────────────────────────
typedef WithdrawalState = AsyncState<()>;
typedef WithdrawalInitial = AsyncInitial<()>;
typedef WithdrawalLoading = AsyncLoading<()>;
typedef WithdrawalLoaded = AsyncLoaded<()>;
typedef WithdrawalError = AsyncError<()>;

// ── Cubit ────────────────────────────────────────────────────────────────────
/// Submits a wallet withdrawal request and tracks its loading/success/error state.
class WithdrawalCubit extends BaseAsyncCubit<()> {
  final WalletRepository _repository;

  WithdrawalCubit({WalletRepository? repository})
    : _repository = repository ?? WalletRepository();

  /// Submit a withdrawal request for the given amount and optional message.
  Future<void> submit({required String amount, String? message}) => run(
    () async {
      await _repository.addWithdrawalRequest(amount: amount, message: message);
      return ();
    },
    onSuccess: (_) => AnalyticsService.instance.logEvent(
      AppConstants.eventWithdrawalRequest,
      parameters: {AppConstants.paramAmount: amount},
    ),
    onUnexpectedError: (e, stack) => CrashlyticsService.instance.recordError(
      e,
      stack,
      reason: 'addWithdrawalRequest failed',
    ),
  );

  /// Reset the cubit back to its initial state.
  void reset() => emit(AsyncInitial());
}
