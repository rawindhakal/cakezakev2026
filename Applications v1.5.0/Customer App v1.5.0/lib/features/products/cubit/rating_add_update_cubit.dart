import 'package:customer/commons/cubit/api_error_guard.dart';
import 'package:customer/features/products/repositories/product_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class RatingAddUpdateState {}

final class RatingAddUpdateInitial extends RatingAddUpdateState {}

final class RatingAddUpdateLoading extends RatingAddUpdateState {}

final class RatingAddUpdateSuccess extends RatingAddUpdateState {
  final String message;
  final Map<String, dynamic>? data;
  RatingAddUpdateSuccess(this.message, {this.data});
}

final class RatingAddUpdateError extends RatingAddUpdateState {
  final String message;
  RatingAddUpdateError(this.message);
}

class RatingAddUpdateCubit extends Cubit<RatingAddUpdateState>
    with ApiErrorGuard<RatingAddUpdateState> {
  final ProductRepository _repository;

  RatingAddUpdateCubit({ProductRepository? repository})
    : _repository = repository ?? ProductRepository(),
      super(RatingAddUpdateInitial());

  Future<void> submit({
    String? productId,
    String? ratingId,
    required String rate,
    required String review,
    List<String>? imagePaths,
    List<String>? deleteImageIds,
  }) async {
    emit(RatingAddUpdateLoading());
    await guard(() async {
      final result = await _repository.addOrUpdateRating(
        productId: productId,
        ratingId: ratingId,
        rate: rate,
        review: review,
        imagePaths: imagePaths,
        deleteImageIds: deleteImageIds,
      );
      emit(RatingAddUpdateSuccess(result.message, data: result.data));
    }, onError: (msg) => emit(RatingAddUpdateError(msg)));
  }

  void reset() => emit(RatingAddUpdateInitial());
}
