import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/blog_category_model.dart';
import '../repositories/blog_repository.dart';
import 'package:customer/commons/cubit/api_error_guard.dart';

// ── States ───────────────────────────────────────────────────────────────────
sealed class BlogCategoryState {}

final class BlogCategoryInitial extends BlogCategoryState {}

final class BlogCategoryLoading extends BlogCategoryState {}

final class BlogCategoryLoaded extends BlogCategoryState {
  final List<BlogCategory> categories;
  BlogCategoryLoaded(this.categories);
}

final class BlogCategoryError extends BlogCategoryState {
  final String message;
  BlogCategoryError(this.message);
}

// ── Cubit ────────────────────────────────────────────────────────────────────
class BlogCategoryCubit extends Cubit<BlogCategoryState>
    with ApiErrorGuard<BlogCategoryState> {
  final BlogRepository _repository;

  BlogCategoryCubit({BlogRepository? repository})
    : _repository = repository ?? BlogRepository(),
      super(BlogCategoryInitial());

  Future<void> loadCategories() async {
    emit(BlogCategoryLoading());
    await guard(() async {
      final result = await _repository.getBlogCategories();
      emit(BlogCategoryLoaded(result.data ?? []));
    }, onError: (msg) => emit(BlogCategoryError(msg)));
  }
}
