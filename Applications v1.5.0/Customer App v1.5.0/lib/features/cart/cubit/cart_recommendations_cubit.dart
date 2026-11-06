import 'package:customer/core/api/api_exception.dart';
import 'package:customer/features/cart/models/cart_recommendations_model.dart';
import 'package:customer/features/cart/repositories/cart_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:customer/core/localization/language_label_key.dart';

sealed class CartRecommendationsState {}

final class CartRecommendationsInitial extends CartRecommendationsState {}

final class CartRecommendationsLoading extends CartRecommendationsState {}

final class CartRecommendationsLoaded extends CartRecommendationsState {
  final CartRecommendations recommendations;
  final bool isLoadingMoreCrossSell;
  final bool isLoadingMoreUpsell;

  CartRecommendationsLoaded(
    this.recommendations, {
    this.isLoadingMoreCrossSell = false,
    this.isLoadingMoreUpsell = false,
  });

  bool get hasMoreCrossSell {
    final block = recommendations.data?.crossSell;
    final total = block?.total;
    if (total == null) return false;
    return (block?.products?.length ?? 0) < total;
  }

  bool get hasMoreUpsell {
    final block = recommendations.data?.upsell;
    final total = block?.total;
    if (total == null) return false;
    return (block?.products?.length ?? 0) < total;
  }
}

final class CartRecommendationsError extends CartRecommendationsState {
  final String message;
  CartRecommendationsError(this.message);
}

class CartRecommendationsCubit extends Cubit<CartRecommendationsState> {
  final CartRepository _repository;
  static const _pageLimit = 10;

  String? _latitude;
  String? _longitude;
  String? _productId;
  int _crossSellPage = 1;
  int _upsellPage = 1;

  CartRecommendationsCubit({CartRepository? repository})
    : _repository = repository ?? CartRepository(),
      super(CartRecommendationsInitial());

  /// [productId] should be passed when fetching from the product detail
  /// screen (recommendations scoped to that product); omit it for the
  /// checkout screen, where recommendations are based on the whole cart.
  Future<void> fetchRecommendations({
    String? latitude,
    String? longitude,
    String? productId,
  }) async {
    _latitude = latitude;
    _longitude = longitude;
    _productId = productId;
    _crossSellPage = 1;
    _upsellPage = 1;
    try {
      emit(CartRecommendationsLoading());
      final result = await _repository.getCartRecommendations(
        latitude: latitude,
        longitude: longitude,
        productId: productId,
        crossSellLimit: _pageLimit,
        crossSellOffset: (_crossSellPage - 1) * _pageLimit,
        upsellLimit: _pageLimit,
        upsellOffset: (_upsellPage - 1) * _pageLimit,
      );
      emit(CartRecommendationsLoaded(result));
    } on ApiException catch (e) {
      emit(CartRecommendationsError(e.message));
    } catch (_) {
      emit(
        CartRecommendationsError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }

  Future<void> loadMoreCrossSell() async {
    final current = state;
    if (current is! CartRecommendationsLoaded) return;
    if (current.isLoadingMoreCrossSell || !current.hasMoreCrossSell) return;

    emit(
      CartRecommendationsLoaded(
        current.recommendations,
        isLoadingMoreCrossSell: true,
        isLoadingMoreUpsell: current.isLoadingMoreUpsell,
      ),
    );
    try {
      final nextPage = _crossSellPage + 1;
      final result = await _repository.getCartRecommendations(
        latitude: _latitude,
        longitude: _longitude,
        productId: _productId,
        crossSellLimit: _pageLimit,
        crossSellOffset: (nextPage - 1) * _pageLimit,
        upsellLimit: _pageLimit,
        upsellOffset: (_upsellPage - 1) * _pageLimit,
      );
      _crossSellPage = nextPage;
      final existing = current.recommendations.data?.crossSell;
      final existingIds = (existing?.products ?? []).map((p) => p.id).toSet();
      final merged = CartRecommendationBlock(
        products: [
          ...(existing?.products ?? []),
          ...(result.data?.crossSell?.products ?? []).where(
            (p) => existingIds.add(p.id),
          ),
        ],
        total: result.data?.crossSell?.total ?? existing?.total,
        limit: existing?.limit,
        offset: nextPage,
      );
      current.recommendations.data?.crossSell = merged;
      emit(
        CartRecommendationsLoaded(
          current.recommendations,
          isLoadingMoreUpsell: current.isLoadingMoreUpsell,
        ),
      );
    } on ApiException catch (e) {
      emit(CartRecommendationsError(e.message));
    } catch (_) {
      emit(
        CartRecommendationsError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }

  Future<void> loadMoreUpsell() async {
    final current = state;
    if (current is! CartRecommendationsLoaded) return;
    if (current.isLoadingMoreUpsell || !current.hasMoreUpsell) return;

    emit(
      CartRecommendationsLoaded(
        current.recommendations,
        isLoadingMoreCrossSell: current.isLoadingMoreCrossSell,
        isLoadingMoreUpsell: true,
      ),
    );
    try {
      final nextPage = _upsellPage + 1;
      final result = await _repository.getCartRecommendations(
        latitude: _latitude,
        longitude: _longitude,
        productId: _productId,
        crossSellLimit: _pageLimit,
        crossSellOffset: (_crossSellPage - 1) * _pageLimit,
        upsellLimit: _pageLimit,
        upsellOffset: (nextPage - 1) * _pageLimit,
      );
      _upsellPage = nextPage;
      final existing = current.recommendations.data?.upsell;
      final existingIds = (existing?.products ?? []).map((p) => p.id).toSet();
      final merged = CartRecommendationBlock(
        products: [
          ...(existing?.products ?? []),
          ...(result.data?.upsell?.products ?? []).where(
            (p) => existingIds.add(p.id),
          ),
        ],
        total: result.data?.upsell?.total ?? existing?.total,
        limit: existing?.limit,
        offset: nextPage,
      );
      current.recommendations.data?.upsell = merged;
      emit(
        CartRecommendationsLoaded(
          current.recommendations,
          isLoadingMoreCrossSell: current.isLoadingMoreCrossSell,
        ),
      );
    } on ApiException catch (e) {
      emit(CartRecommendationsError(e.message));
    } catch (_) {
      emit(
        CartRecommendationsError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }
}
