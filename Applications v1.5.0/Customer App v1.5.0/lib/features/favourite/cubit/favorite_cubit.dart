import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/features/favourite/repositories/favorite_repository.dart';
import 'package:customer/features/products/models/product_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:customer/core/localization/language_label_key.dart';

class FavoriteState {
  final Map<String, bool> favoriteMap;
  final List<ProductDataModel> products;
  final bool listLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int total;
  final String? listError;

  const FavoriteState({
    this.favoriteMap = const {},
    this.products = const [],
    this.listLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.total = 0,
    this.listError,
  });

  bool isFavorite(String? id, {bool fallback = false}) {
    if (id == null) return fallback;
    return favoriteMap[id] ?? fallback;
  }

  FavoriteState copyWith({
    Map<String, bool>? favoriteMap,
    List<ProductDataModel>? products,
    bool? listLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? total,
    String? listError,
    bool clearError = false,
  }) {
    return FavoriteState(
      favoriteMap: favoriteMap ?? this.favoriteMap,
      products: products ?? this.products,
      listLoading: listLoading ?? this.listLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
      listError: clearError ? null : (listError ?? this.listError),
    );
  }
}

class FavoriteCubit extends Cubit<FavoriteState> {
  final FavoriteRepository _repository;

  // See ProductCubit for why grid page size differs from list.
  bool _isGrid = true;
  int get _limit => _isGrid ? AppConfig.gridPageLimit : AppConfig.pageLimit;

  FavoriteCubit({FavoriteRepository? repository})
    : _repository = repository ?? FavoriteRepository(),
      super(const FavoriteState());

  // Re-fetches from the top with the other page size.
  Future<void> setGridView(bool isGrid) {
    if (_isGrid == isGrid) return Future.value();
    _isGrid = isGrid;
    return loadFavorites();
  }

  Future<void> loadFavorites({bool isLoadMore = false}) async {
    try {
      final offset = isLoadMore ? state.products.length : 0;

      if (!isLoadMore) {
        emit(state.copyWith(listLoading: true, clearError: true));
      } else {
        if (state.isLoadingMore || !state.hasMore) return;
        emit(state.copyWith(isLoadingMore: true));
      }

      final result = await _repository.getFavorites(
        offset: offset,
        limit: _limit,
      );
      final items = result.data ?? [];
      final total = result.total ?? 0;

      final merged = {...state.favoriteMap};
      for (final p in items) {
        if (p.id != null) merged[p.id!.toString()] = true;
      }

      final products = isLoadMore ? [...state.products, ...items] : items;

      emit(
        state.copyWith(
          favoriteMap: merged,
          products: products,
          listLoading: false,
          isLoadingMore: false,
          total: total,
          hasMore: products.length < total,
        ),
      );
    } on ApiException catch (e) {
      emit(
        state.copyWith(
          listLoading: false,
          isLoadingMore: false,
          listError: e.message,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          listLoading: false,
          isLoadingMore: false,
          listError: LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }

  Future<void> toggleById(String id, {bool fallback = false}) async {
    final current = state.isFavorite(id, fallback: fallback);
    final next = !current;
    final originalTotal = state.total;

    final map = {...state.favoriteMap, id: next};
    final products = next
        ? state.products
        : state.products.where((p) => p.id?.toString() != id).toList();
    final total = next
        ? originalTotal + 1
        : (originalTotal - 1).clamp(0, 1 << 31);
    emit(state.copyWith(favoriteMap: map, products: products, total: total));

    try {
      if (next) {
        final added = await _repository.addToFavorite(productId: id);
        if (added != null &&
            !state.products.any((p) => p.id?.toString() == id)) {
          emit(state.copyWith(products: [added, ...state.products]));
        }
      } else {
        await _repository.removeFromFavorite(productId: id);
      }
    } catch (_) {
      emit(
        state.copyWith(
          favoriteMap: {...state.favoriteMap, id: current},
          products: state.products,
          total: originalTotal,
        ),
      );
    }
  }

  Future<void> toggle(ProductDataModel product) async {
    final id = product.id;
    if (id == null) return;
    final idStr = id.toString();

    final current = state.isFavorite(
      idStr,
      fallback: product.isFavorite ?? false,
    );
    final next = !current;
    final originalTotal = state.total;

    final map = {...state.favoriteMap, idStr: next};
    List<ProductDataModel> products = state.products;
    if (next) {
      if (!products.any((p) => p.id == id)) products = [product, ...products];
    } else {
      products = products.where((p) => p.id != id).toList();
    }
    final total = next
        ? originalTotal + 1
        : (originalTotal - 1).clamp(0, 1 << 31);
    emit(state.copyWith(favoriteMap: map, products: products, total: total));

    try {
      if (next) {
        final added = await _repository.addToFavorite(productId: idStr);
        if (added != null) {
          final updated = state.products
              .map((p) => p.id == id ? added : p)
              .toList();
          if (!updated.any((p) => p.id == id)) updated.insert(0, added);
          emit(state.copyWith(products: updated));
        }
      } else {
        await _repository.removeFromFavorite(productId: idStr);
      }
    } catch (_) {
      final reverted = {...state.favoriteMap, idStr: current};
      var revertProducts = state.products;
      if (current && !revertProducts.any((p) => p.id == id)) {
        revertProducts = [product, ...revertProducts];
      } else if (!current) {
        revertProducts = revertProducts.where((p) => p.id != id).toList();
      }
      emit(
        state.copyWith(
          favoriteMap: reverted,
          products: revertProducts,
          total: originalTotal,
        ),
      );
    }
  }
}
