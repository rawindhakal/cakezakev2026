import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/features/home/models/home_builder_model.dart';
import 'package:customer/features/home/repositories/home_layout_repository.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:customer/core/localization/language_label_key.dart';

sealed class HomeLayoutState {}

final class HomeLayoutInitial extends HomeLayoutState {}

final class HomeLayoutLoading extends HomeLayoutState {}

final class HomeLayoutLoaded extends HomeLayoutState {
  final HomeBuilderModel homeLayout;
  // True while an additional page of sections is being fetched in the
  // background — the already-rendered sections stay on screen with a
  // loader appended at the bottom instead of a full-screen reload.
  final bool isLoadingMore;
  final bool hasMore;
  HomeLayoutLoaded(
    this.homeLayout, {
    this.isLoadingMore = false,
    this.hasMore = true,
  });

  HomeLayoutLoaded copyWith({
    HomeBuilderModel? homeLayout,
    bool? isLoadingMore,
    bool? hasMore,
  }) => HomeLayoutLoaded(
    homeLayout ?? this.homeLayout,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    hasMore: hasMore ?? this.hasMore,
  );
}

final class HomeLayoutError extends HomeLayoutState {
  final String message;
  HomeLayoutError(this.message);
}

/// Home layout for a single channel. Quick and ecommerce each get their own
/// instance ([QuickHomeLayoutCubit] / [EcommerceHomeLayoutCubit]) so a channel
/// switch keeps the other channel's loaded layout instead of refetching it.
class HomeLayoutCubit extends Cubit<HomeLayoutState> {
  final HomeLayoutRepository _repository;

  /// Channel every request of this cubit is pinned to.
  final String channel;

  HomeLayoutCubit({required this.channel, HomeLayoutRepository? repository})
    : _repository = repository ?? HomeLayoutRepository(),
      super(HomeLayoutInitial());

  int _generation = 0;
  String? _currentCategoryId;
  int _offset = 0;

  static const int _limit = AppConstants.homeSectionsPageLimit;

  /// Category the current/in-flight layout was requested for (null = all).
  String? get currentCategoryId => _currentCategoryId;

  /// Drops the loaded layout (e.g. after a language/location change made it
  /// stale) and discards any in-flight response; next load starts fresh.
  void reset() {
    _generation++;
    _currentCategoryId = null;
    _offset = 0;
    emit(HomeLayoutInitial());
  }

  Future<void> loadHomeLayout({
    String? categoryId,
    bool emitLoadingState = false,
  }) async {
    final generation = ++_generation;
    _currentCategoryId = categoryId;
    _offset = 0;
    try {
      if (emitLoadingState) {
        emit(HomeLayoutLoading());
      }
      final result = await _repository.getHomeLayout(
        channel: channel,
        categoryId: categoryId,
        offset: _offset,
        limit: _limit,
      );
      // Discard stale response: a newer loadHomeLayout (rapid category-tab
      // switch, reset) started after this one and must win, regardless of
      // which network call actually resolves first.
      if (generation != _generation) return;
      final sectionCount = result.data?.layout?.sections?.length ?? 0;
      _offset = sectionCount;
      final total = result.data?.totalSections;
      emit(
        HomeLayoutLoaded(
          result,
          hasMore: total != null ? _offset < total : sectionCount >= _limit,
        ),
      );
    } on ApiException catch (e) {
      if (generation != _generation) return;
      emit(HomeLayoutError(e.message));
    } catch (_) {
      if (generation != _generation) return;
      emit(
        HomeLayoutError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }

  // Fetches the next page of sections and appends them to the currently
  // loaded layout — everything else (header/layout metadata, category
  // tabs, etc.) comes from the first page and is left untouched.
  Future<void> loadMoreSections() async {
    final current = state;
    if (current is! HomeLayoutLoaded ||
        current.isLoadingMore ||
        !current.hasMore) {
      return;
    }
    final generation = _generation;
    emit(current.copyWith(isLoadingMore: true));
    try {
      final result = await _repository.getHomeLayout(
        channel: channel,
        categoryId: _currentCategoryId,
        offset: _offset,
        limit: _limit,
      );
      if (generation != _generation) return;
      final newSections = result.data?.layout?.sections ?? [];
      final mergedSections = [
        ...?current.homeLayout.data?.layout?.sections,
        ...newSections,
      ];
      current.homeLayout.data?.layout?.sections = mergedSections;
      _offset += newSections.length;
      final total =
          result.data?.totalSections ?? current.homeLayout.data?.totalSections;
      emit(
        current.copyWith(
          homeLayout: current.homeLayout,
          isLoadingMore: false,
          hasMore: total != null
              ? _offset < total
              : newSections.length >= _limit,
        ),
      );
    } on ApiException catch (_) {
      if (generation != _generation) return;
      // Load-more failures stay silent — the already-rendered layout is
      // kept, just re-arm hasMore so the next scroll retries.
      emit(current.copyWith(isLoadingMore: false));
    } catch (_) {
      if (generation != _generation) return;
      emit(current.copyWith(isLoadingMore: false));
    }
  }
}

class QuickHomeLayoutCubit extends HomeLayoutCubit {
  QuickHomeLayoutCubit({super.repository}) : super(channel: AppConstants.quick);
}

class EcommerceHomeLayoutCubit extends HomeLayoutCubit {
  EcommerceHomeLayoutCubit({super.repository})
    : super(channel: AppConstants.ecommerce);
}
