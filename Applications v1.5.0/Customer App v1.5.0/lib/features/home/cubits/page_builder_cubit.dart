import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/core/api/api_exception.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/features/home/models/page_builder_model.dart';
import 'package:customer/features/home/repositories/page_builder_repository.dart';
import 'package:customer/core/localization/services/localization_service.dart';
import 'package:customer/core/localization/language_label_key.dart';

sealed class PageBuilderState {}

final class PageBuilderInitial extends PageBuilderState {}

final class PageBuilderLoading extends PageBuilderState {}

final class PageBuilderLoaded extends PageBuilderState {
  final PageBuilderModel pageLayout;
  final bool isLoadingMore;
  final bool hasMore;
  PageBuilderLoaded(
    this.pageLayout, {
    this.isLoadingMore = false,
    this.hasMore = true,
  });

  PageBuilderLoaded copyWith({
    PageBuilderModel? pageLayout,
    bool? isLoadingMore,
    bool? hasMore,
  }) => PageBuilderLoaded(
    pageLayout ?? this.pageLayout,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    hasMore: hasMore ?? this.hasMore,
  );
}

final class PageBuilderError extends PageBuilderState {
  final String message;
  PageBuilderError(this.message);
}

class PageBuilderCubit extends Cubit<PageBuilderState> {
  final PageBuilderRepository _repository;

  PageBuilderCubit({PageBuilderRepository? repository})
    : _repository = repository ?? PageBuilderRepository(),
      super(PageBuilderInitial());

  int _generation = 0;
  // Generation of the sections currently on screen; differs from
  // _generation while a reload is in flight.
  int _loadedGeneration = -1;
  String? _currentId;
  int _offset = 0;

  static const int _limit = AppConstants.homeSectionsPageLimit;

  /// Skeleton only when this page isn't on screen yet (first load, another
  /// id, after an error) or [emitLoadingState] is set. Pull-to-refresh
  /// keeps the current sections until the new page lands, and only the
  /// latest call's response is applied.
  Future<void> loadPageBuilder({
    required String id,
    bool emitLoadingState = false,
  }) async {
    final generation = ++_generation;
    final sameId = id == _currentId;
    _currentId = id;
    _offset = 0;
    try {
      if (emitLoadingState || !sameId || state is! PageBuilderLoaded) {
        emit(PageBuilderLoading());
      }
      final result = await _repository.getPageBuilder(
        id: id,
        offset: _offset,
        limit: _limit,
      );
      // Discard stale response: a newer loadPageBuilder started after this
      // one and must win, regardless of which call resolves first.
      if (generation != _generation) return;
      _loadedGeneration = generation;
      final sectionCount = result.data?.page?.sections?.length ?? 0;
      _offset = sectionCount;
      final total = result.data?.totalSections;
      emit(
        PageBuilderLoaded(
          result,
          hasMore: total != null ? _offset < total : sectionCount >= _limit,
        ),
      );
    } on ApiException catch (e) {
      if (generation != _generation) return;
      emit(PageBuilderError(e.message));
    } catch (_) {
      if (generation != _generation) return;
      emit(
        PageBuilderError(
          LocalizationService.instance.translate(
            LanguageLabelKeys.somethingWentWrong,
          ),
        ),
      );
    }
  }

  Future<void> loadMoreSections() async {
    final current = state;
    if (current is! PageBuilderLoaded ||
        current.isLoadingMore ||
        !current.hasMore ||
        _currentId == null ||
        // Reload in flight — the sections on screen are about to be
        // replaced, appending to them would mix old and new pages.
        _loadedGeneration != _generation) {
      return;
    }
    final generation = _generation;
    emit(current.copyWith(isLoadingMore: true));
    try {
      final result = await _repository.getPageBuilder(
        id: _currentId!,
        offset: _offset,
        limit: _limit,
      );
      if (generation != _generation) return;
      final newSections = result.data?.page?.sections ?? [];
      final mergedSections = [
        ...?current.pageLayout.data?.page?.sections,
        ...newSections,
      ];
      current.pageLayout.data?.page?.sections = mergedSections;
      _offset += newSections.length;
      final total =
          result.data?.totalSections ?? current.pageLayout.data?.totalSections;
      emit(
        current.copyWith(
          pageLayout: current.pageLayout,
          isLoadingMore: false,
          hasMore: total != null
              ? _offset < total
              : newSections.length >= _limit,
        ),
      );
    } on ApiException catch (_) {
      if (generation != _generation) return;
      emit(current.copyWith(isLoadingMore: false));
    } catch (_) {
      if (generation != _generation) return;
      emit(current.copyWith(isLoadingMore: false));
    }
  }
}
