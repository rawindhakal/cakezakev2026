import 'package:customer/commons/cubit/api_error_guard.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/features/products/models/product_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/product_repository.dart';

sealed class RecentlyVisitedState {}

final class RecentlyVisitedInitial extends RecentlyVisitedState {}

final class RecentlyVisitedLoading extends RecentlyVisitedState {}

final class RecentlyVisitedLoaded extends RecentlyVisitedState {
  final List<ProductDataModel> products;
  final int total;

  RecentlyVisitedLoaded({required this.products, required this.total});
}

final class RecentlyVisitedError extends RecentlyVisitedState {
  final String message;
  RecentlyVisitedError(this.message);
}

class RecentlyVisitedCubit extends Cubit<RecentlyVisitedState>
    with ApiErrorGuard<RecentlyVisitedState> {
  final ProductRepository _repository;

  RecentlyVisitedCubit({ProductRepository? repository})
    : _repository = repository ?? ProductRepository(),
      super(RecentlyVisitedInitial());

  Future<void> getRecentlyVisited({String? productId}) async {
    if (!AuthHiveBox.instance.isLoggedIn) return;
    emit(RecentlyVisitedLoading());
    await guard(() async {
      final result = await _repository.getRecentlyVisited(productId: productId);
      emit(
        RecentlyVisitedLoaded(
          products: result.data ?? [],
          total: result.total ?? 0,
        ),
      );
    }, onError: (msg) => emit(RecentlyVisitedError(msg)));
  }
}
