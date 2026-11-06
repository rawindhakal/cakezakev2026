import 'package:customer/commons/cubit/api_error_guard.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/features/products/repositories/product_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class AddRecentlyVisitedProductState {}

final class AddRecentlyVisitedProductInitial
    extends AddRecentlyVisitedProductState {}

final class AddRecentlyVisitedProductLoading
    extends AddRecentlyVisitedProductState {}

final class AddRecentlyVisitedProductLoaded
    extends AddRecentlyVisitedProductState {
  final String message;
  AddRecentlyVisitedProductLoaded(this.message);
}

final class AddRecentlyVisitedProductError
    extends AddRecentlyVisitedProductState {
  final String message;
  AddRecentlyVisitedProductError(this.message);
}

class AddRecentlyVisitedProductCubit
    extends Cubit<AddRecentlyVisitedProductState>
    with ApiErrorGuard<AddRecentlyVisitedProductState> {
  final ProductRepository _repository;

  AddRecentlyVisitedProductCubit({ProductRepository? repository})
    : _repository = repository ?? ProductRepository(),
      super(AddRecentlyVisitedProductInitial());

  Future<void> addRecentlyVisitedProduct({required String productId}) async {
    if (!AuthHiveBox.instance.isLoggedIn) return;
    emit(AddRecentlyVisitedProductLoading());
    await guard(() async {
      final message = await _repository.addRecentlyVisitedProduct(
        productId: productId,
      );
      emit(AddRecentlyVisitedProductLoaded(message));
    }, onError: (msg) => emit(AddRecentlyVisitedProductError(msg)));
  }
}
