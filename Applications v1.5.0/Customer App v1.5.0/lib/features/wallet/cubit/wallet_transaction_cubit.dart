import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/features/wallet/models/wallet_history_model.dart';
import 'package:customer/features/wallet/repositories/wallet_repository.dart';

class WalletTransactionCubit extends BasePaginationCubit<WalletHistoryData> {
  final WalletRepository _repo;

  WalletTransactionCubit({WalletRepository? repository})
    : _repo = repository ?? WalletRepository();

  @override
  PaginationFetcher<WalletHistoryData> get fetcher =>
      (offset) =>
          _repo.getWalletHistory(offset: offset, limit: AppConfig.pageLimit);
}
