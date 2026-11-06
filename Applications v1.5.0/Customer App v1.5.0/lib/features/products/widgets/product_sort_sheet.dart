import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/products/cubit/product_cubit.dart';
import 'package:customer/features/products/models/product_sort_type.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/commons/animations/slide_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/widgets/app_radio_option_tile.dart';
import 'package:customer/utils/show_app_bottom_sheet.dart';
import 'package:customer/core/constants/theme_constants.dart';

void showProductSortSheet(
  BuildContext context,
  ProductSortType currentSort, {
  ValueChanged<ProductSortType>? onSelect,
}) {
  final apply = onSelect ?? context.read<ProductCubit>().applySort;
  showAppBottomSheet(
    context,
    title: context.translate(LanguageLabelKeys.sortBy),
    padding: const EdgeInsetsDirectional.fromSTEB(
      ThemeConstants.paddingL,
      ThemeConstants.paddingM,
      ThemeConstants.paddingL,
      ThemeConstants.paddingXXL,
    ),
    enableDrag: true,
    builder: (sheetContext) => _ProductSortSheet(
      currentSort: currentSort,
      onSelect: (sort) {
        apply(sort);
        AppNavigator.pop(sheetContext);
      },
    ),
  );
}

class _ProductSortSheet extends StatelessWidget {
  final ProductSortType currentSort;
  final ValueChanged<ProductSortType> onSelect;

  const _ProductSortSheet({required this.currentSort, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final sorts = ProductSortType.values;
    return RadioGroup<ProductSortType>(
      groupValue: currentSort,
      onChanged: (sort) {
        if (sort != null) onSelect(sort);
      },
      child: SlideAnimationList(
        children: [
          for (final sort in sorts)
            AppRadioOptionTile<ProductSortType>(
              value: sort,
              title: context.translate(sort.labelKey()),
              selected: sort == currentSort,
              showContainerDecoration: false,
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: ThemeConstants.paddingM,
              ),
              onTap: () => onSelect(sort),
            ),
        ],
      ),
    );
  }
}
