import 'package:customer/features/products/models/filter_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_exception.dart';
import '../repositories/product_repository.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:customer/core/localization/language_label_key.dart';

sealed class FilterState {}

final class FilterInitial extends FilterState {}

final class FilterLoading extends FilterState {}

final class FilterLoaded extends FilterState {
  final FilterModelData data;
  FilterLoaded(this.data);
}

final class FilterError extends FilterState {
  final String message;
  FilterError(this.message);
}

class FilterCubit extends Cubit<FilterState> {
  final ProductRepository _repository;

  FilterCubit({ProductRepository? repository})
    : _repository = repository ?? ProductRepository(),
      super(FilterInitial());

  Future<void> loadFilters({
    String? categoryId,
    String? dataSource,
    String? manualProductIds,
    String? brandIds,
    String? filterMode,
    String? attributeValueIds,
    double? minPrice,
    double? maxPrice,
    String? minDiscountPercent,
    String? maxDiscountPercent,
  }) async {
    try {
      emit(FilterLoading());
      final result = await _repository.getFilters(
        categoryId: categoryId,
        dataSource: dataSource,
        manualProductIds: manualProductIds,
        brandIds: brandIds,
        filterMode: filterMode,
        attributeValueIds: attributeValueIds,
        minPrice: minPrice,
        maxPrice: maxPrice,
        minDiscountPercent: minDiscountPercent,
        maxDiscountPercent: maxDiscountPercent,
      );
      if (result.data != null) {
        emit(FilterLoaded(result.data!));
      } else {
        emit(FilterError(result.message ?? ''));
      }
    } on ApiException catch (e) {
      emit(FilterError(e.message));
    } catch (_) {
      emit(
        FilterError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }
}
