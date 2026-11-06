import 'package:customer/features/category/models/category_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum SubCategorySwipe { none, next, previous }

sealed class SubCategorySelectionState {}

final class SubCategorySelectionInitial extends SubCategorySelectionState {}

final class SubCategorySelectionActive extends SubCategorySelectionState {
  final String leftSelectedId;
  final Category rightCategory;
  final bool rightShowsSubcategories;
  // How this selection was reached. A swipe past either end of the product
  // list slides the new content in from that side; a tap just swaps it.
  final SubCategorySwipe swipe;

  SubCategorySelectionActive({
    required this.leftSelectedId,
    required this.rightCategory,
    required this.rightShowsSubcategories,
    this.swipe = SubCategorySwipe.none,
  });
}

/// Drives which left-panel item is highlighted and what the right panel
/// shows on a single SubCategoryScreen. Both the first auto-selected item
/// and every manual left-panel tap go through [selectLeft] so they share
/// one rule: has_child == true -> right panel previews its subcategories
/// in place, has_child == false -> right panel shows its products in place.
/// (Tapping an item inside that right-panel subcategory preview instead
/// pushes a new screen — see SubCategoryScreen._onSelectRightItem.)
class SubCategorySelectionCubit extends Cubit<SubCategorySelectionState> {
  SubCategorySelectionCubit() : super(SubCategorySelectionInitial());

  void selectLeft(
    Category category, {
    SubCategorySwipe swipe = SubCategorySwipe.none,
  }) {
    final id = category.id ?? '';
    final current = state;
    if (current is SubCategorySelectionActive &&
        current.leftSelectedId == id &&
        current.rightCategory.id == id) {
      return;
    }
    emit(
      SubCategorySelectionActive(
        leftSelectedId: id,
        rightCategory: category,
        rightShowsSubcategories: category.hasChild == true,
        swipe: swipe,
      ),
    );
  }
}
