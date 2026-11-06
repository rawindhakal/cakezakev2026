import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/features/wallet/models/transaction_model.dart';
import 'package:customer/features/wallet/repositories/wallet_repository.dart';

class TransactionCubit extends BasePaginationCubit<TransactionData> {
  final WalletRepository _repo;

  TransactionCubit({WalletRepository? repository})
    : _repo = repository ?? WalletRepository();

  @override
  PaginationFetcher<TransactionData> get fetcher =>
      (offset) =>
          _repo.getUserTransactions(offset: offset, limit: AppConfig.pageLimit);
}
