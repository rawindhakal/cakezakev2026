import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/blog/cubit/blog_category_cubit.dart';
import 'package:customer/features/blog/cubit/blog_cubit.dart';
import 'package:customer/features/blog/models/blog_model.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/core/constants/theme_constants.dart';

class CategoryFilterBar extends StatelessWidget {
  const CategoryFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BlogCategoryCubit, BlogCategoryState>(
      builder: (context, catState) {
        if (catState is! BlogCategoryLoaded || catState.categories.isEmpty) {
          return AppSpacing.shrink;
        }

        return BlocBuilder<BlogCubit, PaginationState<Blog>>(
          builder: (context, blogState) {
            final selectedId = context.read<BlogCubit>().currentFilters;

            return SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: ThemeConstants.paddingL,
                  vertical: ThemeConstants.paddingS,
                ),
                children: [
                  CategoryChip(
                    label: context.translate(LanguageLabelKeys.filterAll),
                    isSelected: selectedId == null,
                    onTap: () =>
                        context.read<BlogCubit>().filterByCategory(null),
                  ),
                  ...catState.categories.map(
                    (cat) => CategoryChip(
                      label: cat.name ?? '',
                      isSelected: selectedId == cat.id,
                      onTap: () =>
                          context.read<BlogCubit>().filterByCategory(cat.id),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsetsDirectional.only(end: ThemeConstants.paddingS),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ThemeConstants.paddingM,
          vertical: ThemeConstants.paddingXS,
        ),
        alignment: AlignmentDirectional.center,
        decoration: AppDecorations.box(
          color: isSelected ? context.cs.primary : context.cs.surface,
          borderRadius: AppRadius.r20,
          border: Border.all(
            color: isSelected ? context.cs.primary : context.cs.outlineVariant,
          ),
        ),
        child: AppText(
          label,
          style: context.tt.bodySmall?.copyWith(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? context.cs.onPrimary : context.cs.onSurface,
          ),
        ),
      ),
    );
  }
}
