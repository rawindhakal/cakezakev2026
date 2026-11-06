import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:deliveryboy/commons/widgets/empty_state_widget.dart';
import 'package:deliveryboy/commons/widgets/paginated_list_view.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import '../models/cash_collection_model.dart';
import 'cash_collection_card.dart';

/// Paginated, pull-to-refresh list of cash collection entries.
class CashCollectionList extends StatelessWidget {
  final List<CashCollectionModel> collections;
  final bool isLoadingMore;
  final bool hasMore;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;

  /// Scrolls with the list as its first item (the summary card).
  final Widget? header;

  /// Overlaid under the app bar (e.g. a sticky summary bar).
  final Widget? overlay;

  const CashCollectionList({
    super.key,
    required this.collections,
    required this.isLoadingMore,
    required this.hasMore,
    required this.scrollController,
    required this.onRefresh,
    this.header,
    this.overlay,
  });

  @override
  Widget build(BuildContext context) {
    if (collections.isEmpty) {
      return EmptyStateWidget(
        imagePath: AssetsConstants.noCaseCollectionFound,
        title: context.translate(LanguageLabelKeys.noCashCollections),
        subtitle: context.translate(LanguageLabelKeys.noCashCollectionsDesc),
      );
    }

    final list = PaginatedListView<CashCollectionModel>(
      header: header,
      items: collections,
      isLoadingMore: isLoadingMore,
      hasMore: hasMore,
      scrollController: scrollController,
      onRefresh: onRefresh,
      refreshBackgroundColor: context.cs.surface,
      refreshStrokeWidth: 2.5,
      // With a header the list is full-width (the header card brings its own
      // side margin) and each card gets its side padding below — otherwise
      // the header would be inset twice.
      padding: EdgeInsetsDirectional.fromSTEB(
        header != null ? 0 : ThemeConstants.paddingL,
        header != null ? 0 : ThemeConstants.paddingS,
        header != null ? 0 : ThemeConstants.paddingL,
        ThemeConstants.spaceXXXL + context.bottomSafePadding,
      ),
      itemBuilder: (context, item, index) => header == null
          ? CashCollectionCard(item: item)
          : Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: ThemeConstants.paddingL,
              ),
              child: CashCollectionCard(item: item),
            ),
    );
    if (overlay == null) return list;
    return Stack(
      children: [
        list,
        PositionedDirectional(top: 0, start: 0, end: 0, child: overlay!),
      ],
    );
  }
}
