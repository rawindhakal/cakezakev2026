import 'package:deliveryboy/commons/widgets/empty_state_widget.dart';
import 'package:deliveryboy/commons/widgets/paginated_list_view.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/settlement_history/models/settlement_history_model.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'settlement_history_card.dart';

/// Paginated, pull-to-refresh list of fund transfer/settlement entries.
class TransferList extends StatelessWidget {
  final List<SettlementHistoryData> transfers;
  final bool isLoadingMore;
  final bool hasMore;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;

  const TransferList({
    super.key,
    required this.transfers,
    required this.isLoadingMore,
    required this.hasMore,
    required this.scrollController,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (transfers.isEmpty) {
      return EmptyStateWidget(
        imagePath: AssetsConstants.noFundFound,
        title: context.translate(LanguageLabelKeys.noSettlementHistory),
        subtitle: context.translate(LanguageLabelKeys.noSettlementHistory),
      );
    }
    return PaginatedListView<SettlementHistoryData>(
      items: transfers,
      isLoadingMore: isLoadingMore,
      hasMore: hasMore,
      scrollController: scrollController,
      onRefresh: onRefresh,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsetsDirectional.fromSTEB(
        ThemeConstants.paddingL,
        ThemeConstants.paddingM,
        ThemeConstants.paddingL,
        context.bottomSafePadding,
      ),
      itemBuilder: (context, item, index) => SettlementHistoryCard(item: item),
    );
  }
}
