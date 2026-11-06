import 'package:deliveryboy/commons/widgets/empty_state_widget.dart';
import 'package:deliveryboy/commons/widgets/paginated_list_view.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import '../models/salary_model.dart';
import 'salary_card.dart';

/// Paginated, pull-to-refresh list of salary payment entries.
class SalaryList extends StatelessWidget {
  final List<SalaryModel> salaries;
  final int total;
  final bool isLoadingMore;
  final bool hasMore;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;

  const SalaryList({
    super.key,
    required this.salaries,
    required this.total,
    required this.isLoadingMore,
    required this.hasMore,
    required this.scrollController,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (salaries.isEmpty) {
      return EmptyStateWidget(
        imagePath: AssetsConstants.noSalaryFound,
        title: context.translate(LanguageLabelKeys.noSalaryRecords),
        subtitle: context.translate(LanguageLabelKeys.noSalaryDesc),
      );
    }

    return PaginatedListView<SalaryModel>(
      items: salaries,
      isLoadingMore: isLoadingMore,
      hasMore: hasMore,
      scrollController: scrollController,
      onRefresh: onRefresh,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsetsDirectional.fromSTEB(ThemeConstants.paddingL, ThemeConstants.paddingM, ThemeConstants.paddingL, context.bottomSafePadding),
      itemBuilder: (context, item, index) => SalaryCard(item: item),
    );
  }
}
