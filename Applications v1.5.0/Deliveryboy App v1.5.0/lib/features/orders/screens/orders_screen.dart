import 'package:deliveryboy/commons/cubit/connectivity_cubit.dart';
import 'package:deliveryboy/commons/utils/pagination_scroll_controller.dart';
import 'package:deliveryboy/commons/widgets/app_date_range_picker.dart';
import 'package:deliveryboy/commons/widgets/app_no_internet_widget.dart';
import 'package:deliveryboy/commons/widgets/app_button.dart';
import 'package:deliveryboy/commons/widgets/app_scaffold.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/commons/widgets/custom_app_bar.dart';
import 'package:deliveryboy/commons/widgets/date_range_filter_field.dart';
import 'package:deliveryboy/commons/widgets/empty_state_widget.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/features/orders/widgets/order_skeletons.dart';
import 'package:deliveryboy/core/constants/app_constants.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/navigation_service.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/theme/app_radius.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/features/orders/cubit/ecommerce_order_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/order_status_list_filter_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/return_order_cubit.dart';
import 'package:deliveryboy/features/orders/cubit/return_order_status_list_filter_cubit.dart';
import 'package:deliveryboy/features/orders/widgets/ecommerce_order_card.dart';
import 'package:deliveryboy/features/orders/widgets/order_card.dart';
import 'package:deliveryboy/features/orders/widgets/order_list_view.dart';
import 'package:deliveryboy/features/orders/widgets/return_order_card.dart';
import 'package:deliveryboy/features/orders/widgets/status_filter_chips.dart';
import 'package:deliveryboy/core/routes/route_names.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:deliveryboy/utils/extensions/string_extensions.dart';
import 'package:deliveryboy/utils/show_app_bottom_sheet.dart';
import 'package:deliveryboy/commons/widgets/app_text.dart';

import 'package:flutter/material.dart';
import 'package:deliveryboy/core/theme/app_decorations.dart';
import 'package:deliveryboy/commons/animations/slide_animation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:deliveryboy/commons/cubit/base_pagination_cubit.dart';
import '../models/order_model.dart';
import '../models/ecommerce_order_model.dart';
import '../models/return_order_model.dart';
import '../cubit/order_cubit.dart';

/// Tabbed list screen for quick, ecommerce, and return orders with status/date filters.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _searchController = TextEditingController();
  late final PaginationScrollController _scrollController;
  late final PaginationScrollController _ecommerceScrollController;
  late final PaginationScrollController _returnScrollController;
  int _selectedTypeIndex = 0;
  bool _isSearching = false;

  bool get _isQuick => _selectedTypeIndex == 0;
  bool get _isReturn => _selectedTypeIndex == 2;
  bool get _showSearch => _isQuick || _isReturn;

  ScrollController get _activeScrollController => switch (_selectedTypeIndex) {
    1 => _ecommerceScrollController.controller,
    2 => _returnScrollController.controller,
    _ => _scrollController.controller,
  };

  @override
  void initState() {
    super.initState();
    context.read<OrderCubit>().loadOrders();
    context.read<EcommerceOrderCubit>().loadOrders();
    context.read<ReturnOrderCubit>().loadOrders();
    context.read<OrderStatusListFilterCubit>().orderStatusesFilter(
      channel: AppConstants.quick,
    );
    context
        .read<ReturnOrderStatusListFilterCubit>()
        .returnOrderStatusesFilter();
    _scrollController = PaginationScrollController(
      onLoadMore: () => context.read<OrderCubit>().loadMore(),
    );
    _ecommerceScrollController = PaginationScrollController(
      onLoadMore: () => context.read<EcommerceOrderCubit>().loadMore(),
    );
    _returnScrollController = PaginationScrollController(
      onLoadMore: () => context.read<ReturnOrderCubit>().loadMore(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _ecommerceScrollController.dispose();
    _returnScrollController.dispose();
    super.dispose();
  }

  void _changeType(int index) {
    if (_selectedTypeIndex == index) return;
    if (_isSearching) _searchController.clear();
    setState(() {
      _selectedTypeIndex = index;
      _isSearching = false;
    });
    if (index == 0) {
      context.read<OrderStatusListFilterCubit>().orderStatusesFilter(
        channel: AppConstants.quick,
      );
    } else if (index == 2) {
      context
          .read<ReturnOrderStatusListFilterCubit>()
          .returnOrderStatusesFilter();
    } else {
      context.read<OrderStatusListFilterCubit>().orderStatusesFilter(
        channel: AppConstants.ecommerce,
      );
    }
  }

  void _applyFilters(int type, Map<int, (String?, String?)> tempDates) {
    _changeType(type);
    final search = _searchController.text.trim();

    // Only refetch the list for the order type selected in the sheet —
    // the other two tabs' filters weren't touched, so they shouldn't refire.
    switch (type) {
      case 0:
        final (s0, e0) = tempDates[0]!;
        final c0 = context.read<OrderCubit>();
        c0.updateFilters(
          status: c0.selectedStatus,
          search: search,
          startDate: s0,
          endDate: e0,
        );
        break;
      case 1:
        final (s1, e1) = tempDates[1]!;
        final c1 = context.read<EcommerceOrderCubit>();
        c1.updateFilters(status: c1.selectedStatus, startDate: s1, endDate: e1);
        break;
      case 2:
        final (s2, e2) = tempDates[2]!;
        final c2 = context.read<ReturnOrderCubit>();
        c2.updateFilters(
          status: c2.selectedStatus,
          search: search,
          startDate: s2,
          endDate: e2,
        );
        break;
    }
  }

  void _clearAllFilters() {
    _searchController.clear();
    setState(() {
      _selectedTypeIndex = 0;
      _isSearching = false;
    });
    context.read<OrderCubit>().clearFilters();
    context.read<EcommerceOrderCubit>().clearFilters();
    context.read<ReturnOrderCubit>().clearFilters();
    context.read<OrderStatusListFilterCubit>().orderStatusesFilter(
      channel: AppConstants.quick,
    );
  }

  void _showFilterSheet() {
    int tempType = _selectedTypeIndex;
    final tempDates = <int, (String?, String?)>{
      0: (
        context.read<OrderCubit>().startDate,
        context.read<OrderCubit>().endDate,
      ),
      1: (
        context.read<EcommerceOrderCubit>().startDate,
        context.read<EcommerceOrderCubit>().endDate,
      ),
      2: (
        context.read<ReturnOrderCubit>().startDate,
        context.read<ReturnOrderCubit>().endDate,
      ),
    };

    showAppBottomSheet(
      context,
      isScrollControlled: true,
      title: context.translate(LanguageLabelKeys.filters),
      padding: const EdgeInsetsDirectional.fromSTEB(ThemeConstants.paddingXL, ThemeConstants.paddingM, ThemeConstants.paddingXL, ThemeConstants.paddingXXL),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final (startDate, endDate) = tempDates[tempType]!;

          return SlideAnimationList(
            crossAxisAlignment: .start,
            children: [
              AppText(
                ctx.translate(LanguageLabelKeys.orderType),
                style: ctx.tt.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: ctx.cs.onSurfaceVariant,
                ),
              ),
              AppSpacing.h10,
              Row(
                children: [
                  _OrderTypeChip(
                    label: ctx.translate(LanguageLabelKeys.quickTab),
                    selected: tempType == 0,
                    onTap: () => setSheetState(() => tempType = 0),
                  ),
                  AppSpacing.w8,
                  _OrderTypeChip(
                    label: ctx.translate(LanguageLabelKeys.ecommerceTab),
                    selected: tempType == 1,
                    onTap: () => setSheetState(() => tempType = 1),
                  ),
                  AppSpacing.w8,
                  _OrderTypeChip(
                    label: ctx.translate(LanguageLabelKeys.returnsTab),
                    selected: tempType == 2,
                    onTap: () => setSheetState(() => tempType = 2),
                  ),
                ],
              ),
              AppSpacing.h20,
              AppText(
                ctx.translate(LanguageLabelKeys.dateRange),
                style: ctx.tt.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: ctx.cs.onSurfaceVariant,
                ),
              ),
              AppSpacing.h10,
              DateRangeFilterField(
                startDate: startDate,
                endDate: endDate,
                onTap: () async {
                  final now = DateTime.now();
                  final range = await showAppDateRangePicker(
                    context: context,
                    firstDate: DateTime(now.year - 2),
                    lastDate: now,
                    initialDateRange: startDate != null && endDate != null
                        ? DateTimeRange(
                            start: DateTime.parse(startDate),
                            end: DateTime.parse(endDate),
                          )
                        : null,
                  );
                  if (range != null) {
                    setSheetState(() {
                      tempDates[tempType] = (
                        range.start.toApiDateString(),
                        range.end.toApiDateString(),
                      );
                    });
                  }
                },
                onClear: () =>
                    setSheetState(() => tempDates[tempType] = (null, null)),
              ),
              AppSpacing.h28,
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: ctx.translate(LanguageLabelKeys.clear),
                      variant: AppButtonVariant.outline,
                      height: ctx.heightFraction(0.05),
                      onPressed: () {
                        AppNavigator.pop(sheetCtx);
                        // Only re-fetch when a filter is actually applied —
                        // otherwise there's nothing to clear server-side, so
                        // just close the sheet.
                        if (_hasActiveFilters()) _clearAllFilters();
                      },
                    ),
                  ),
                  AppSpacing.w12,
                  Expanded(
                    child: AppButton(
                      label: ctx.translate(LanguageLabelKeys.apply),
                      height: ctx.heightFraction(0.05),
                      onPressed: () {
                        AppNavigator.pop(sheetCtx);
                        _applyFilters(tempType, tempDates);
                      },
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _onStatusChanged(String status) {
    if (_isQuick) {
      final c = context.read<OrderCubit>();
      c.updateFilters(
        status: status,
        search: _searchController.text.trim(),
        startDate: c.startDate,
        endDate: c.endDate,
      );
    } else if (_isReturn) {
      final c = context.read<ReturnOrderCubit>();
      c.updateFilters(
        status: status,
        search: _searchController.text.trim(),
        startDate: c.startDate,
        endDate: c.endDate,
      );
    } else {
      final c = context.read<EcommerceOrderCubit>();
      c.updateFilters(
        status: status,
        startDate: c.startDate,
        endDate: c.endDate,
      );
    }
  }

  void _onSearchSubmit(String value) {
    if (_isQuick) {
      final c = context.read<OrderCubit>();
      c.updateFilters(
        status: c.selectedStatus,
        search: value.trim(),
        startDate: c.startDate,
        endDate: c.endDate,
      );
    } else if (_isReturn) {
      final c = context.read<ReturnOrderCubit>();
      c.updateFilters(
        status: c.selectedStatus,
        search: value.trim(),
        startDate: c.startDate,
        endDate: c.endDate,
      );
    }
  }

  void _startSearch() => setState(() => _isSearching = true);

  void _cancelSearch() {
    setState(() => _isSearching = false);
    final hadText = _searchController.text.trim().isNotEmpty;
    _searchController.clear();
    if (hadText) _onSearchSubmit('');
  }

  bool _hasActiveFilters() {
    if (_selectedTypeIndex != 0) return true;
    return context.read<OrderCubit>().hasActiveFilters ||
        context.read<EcommerceOrderCubit>().hasActiveFilters ||
        context.read<ReturnOrderCubit>().hasActiveFilters;
  }

  /// Refetches every list this screen can show — all three live in an
  /// [IndexedStack], so any of them may be the visible one after a reload.
  void _reloadAll(BuildContext context) {
    context.read<OrderStatusListFilterCubit>().orderStatusesFilter();
    context
        .read<ReturnOrderStatusListFilterCubit>()
        .returnOrderStatusesFilter();
    context.read<OrderCubit>().loadOrders();
    context.read<EcommerceOrderCubit>().loadOrders();
    context.read<ReturnOrderCubit>().loadOrders();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ConnectivityCubit, ConnectivityState>(
      listener: (context, state) {
        if (state is ConnectivityConnected) _reloadAll(context);
      },
      builder: (context, connectivityState) {
        final isOffline = connectivityState is ConnectivityDisconnected;
        return AppScaffold(
          applyBottomInset: false,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: CustomAppBar(
            title: context.translate(LanguageLabelKeys.myDelivery),
            showBackButton: false,
            scrollController: _activeScrollController,
            isSearching: _showSearch && _isSearching,
            searchController: _searchController,
            onSearchChanged: _showSearch ? _onSearchSubmit : null,
            onSearchStart: _showSearch ? _startSearch : null,
            onSearchCancel: _showSearch ? _cancelSearch : null,
            searchHint: context.translate(
              _isReturn
                  ? LanguageLabelKeys.searchReturnOrders
                  : LanguageLabelKeys.searchOrders,
            ),
            // Status chips would sit above an empty body while offline.
            bottom: isOffline
                ? null
                : PreferredSize(
                    preferredSize: Size.fromHeight(context.screenHeight * 0.054),
                    child: _isReturn
                        ? ReturnStatusChips(onStatusChanged: _onStatusChanged)
                        : OrderStatusChips(
                            onStatusChanged: _onStatusChanged,
                            isEcommerce: !_isQuick,
                          ),
                  ),
            actions: [
              IconButton(
                icon: AppSvgIcon(
                  AssetsConstants.scannerIcon,
                  size: ThemeConstants.iconS,
                  color: context.cs.onSurfaceVariant,
                ),
                onPressed: () => AppNavigator.pushNamed(
                  context,
                  RouteNames.orderScanner,
                ),
                tooltip: context.translate(LanguageLabelKeys.scanQrCode),
              ),
              Stack(
                clipBehavior: .none,
                children: [
                  IconButton(
                    icon: AppSvgIcon(
                      AssetsConstants.filterIcon,
                      size: ThemeConstants.iconS,
                      color: context.cs.onSurfaceVariant,
                    ),
                    onPressed: _showFilterSheet,
                    tooltip: context.translate(LanguageLabelKeys.filters),
                  ),
                  if (_hasActiveFilters())
                    PositionedDirectional(
                      end: 10,
                      top: 10,
                      child: Container(
                        width: context.screenWidth * 0.019,
                        height: context.screenWidth * 0.019,
                        decoration: AppDecorations.circle(
                          color: context.cs.primary,
                        ),
                      ),
                    ),
                ],
              ),
              AppSpacing.w4,
            ],
          ),
          // Offline state lives in the body so the tab keeps its app bar and
          // the bottom navigation bar stays reachable.
          body: isOffline
              ? AppNoInternetFullScreen(
                  embedded: true,
                  onRetry: () => _reloadAll(context),
                )
              : IndexedStack(
                  index: _selectedTypeIndex,
                  children: [
                    BlocBuilder<OrderCubit, PaginationState<OrderData>>(
                      builder: (context, state) {
                        if (state is PaginationLoading<OrderData>) {
                          return const OrderListSkeleton();
                        }
                        if (state is PaginationError<OrderData>) {
                          return EmptyStateWidget(
                            imagePath: AssetsConstants.noOrderFound,
                            title: state.message,
                            subtitle: context.translate(
                              LanguageLabelKeys.pullDownToRefresh,
                            ),
                            onRetry: () =>
                                context.read<OrderCubit>().loadOrders(),
                          );
                        }
                        if (state is PaginationLoaded<OrderData>) {
                          return OrderListView<OrderData>(
                            items: state.data,
                            isLoadingMore: state.isFetchingMore,
                            hasMore: state.hasMore,
                            scrollController: _scrollController.controller,
                            onRefresh: () =>
                                context.read<OrderCubit>().loadOrders(),
                            emptyImagePath: AssetsConstants.noOrderFound,
                            emptyTitle: context.translate(
                              LanguageLabelKeys.noOrdersFound,
                            ),
                            emptySubtitle: context.translate(
                              LanguageLabelKeys.noOrdersYet,
                            ),
                            itemBuilder: (context, order, index) => OrderCard(
                              order: order,
                              onTap: () => AppNavigator.pushNamed(
                                context,
                                RouteNames.orderDetail,
                                arguments:
                                    (order.id ?? order.orderId)?.toString() ??
                                        '',
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    BlocBuilder<
                      EcommerceOrderCubit,
                      PaginationState<EcommerceOrderDataModel>
                    >(
                      builder: (context, state) {
                        if (state
                            is PaginationLoading<EcommerceOrderDataModel>) {
                          return const OrderListSkeleton(
                            variant: OrderSkeletonVariant.ecommerce,
                          );
                        }
                        if (state is PaginationError<EcommerceOrderDataModel>) {
                          return EmptyStateWidget(
                            imagePath: AssetsConstants.noOrderFound,
                            title: state.message,
                            subtitle: context.translate(
                              LanguageLabelKeys.pullDownToRefresh,
                            ),
                            onRetry: () => context
                                .read<EcommerceOrderCubit>()
                                .loadOrders(),
                          );
                        }
                        if (state
                            is PaginationLoaded<EcommerceOrderDataModel>) {
                          return OrderListView<EcommerceOrderDataModel>(
                            items: state.data,
                            isLoadingMore: state.isFetchingMore,
                            hasMore: state.hasMore,
                            scrollController: _ecommerceScrollController.controller,
                            onRefresh: () => context
                                .read<EcommerceOrderCubit>()
                                .loadOrders(),
                            emptyImagePath: AssetsConstants.noOrderFound,
                            emptyTitle: context.translate(
                              LanguageLabelKeys.noOrdersFound,
                            ),
                            emptySubtitle: context.translate(
                              LanguageLabelKeys.noOrdersYet,
                            ),
                            itemBuilder: (context, order, index) =>
                                EcommerceOrderCard(
                              order: order,
                              onTap: () => AppNavigator.pushNamed(
                                context,
                                RouteNames.ecommerceOrderDetail,
                                arguments: order.id?.toString() ?? '',
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    BlocBuilder<
                      ReturnOrderCubit,
                      PaginationState<ReturnRequestData>
                    >(
                      builder: (context, state) {
                        if (state is PaginationLoading<ReturnRequestData>) {
                          return const OrderListSkeleton(
                            variant: OrderSkeletonVariant.returns,
                          );
                        }
                        if (state is PaginationError<ReturnRequestData>) {
                          return EmptyStateWidget(
                            imagePath: AssetsConstants.noOrderFound,
                            title: state.message,
                            subtitle: context.translate(
                              LanguageLabelKeys.pullDownToRefresh,
                            ),
                            onRetry: () =>
                                context.read<ReturnOrderCubit>().loadOrders(),
                          );
                        }
                        if (state is PaginationLoaded<ReturnRequestData>) {
                          return OrderListView<ReturnRequestData>(
                            items: state.data,
                            isLoadingMore: state.isFetchingMore,
                            hasMore: state.hasMore,
                            scrollController: _returnScrollController.controller,
                            onRefresh: () =>
                                context.read<ReturnOrderCubit>().loadOrders(),
                            physics: const AlwaysScrollableScrollPhysics(),
                            emptyImagePath: AssetsConstants.noOrderFound,
                            emptyTitle: context.translate(
                              LanguageLabelKeys.noReturnRequests,
                            ),
                            emptySubtitle: context.translate(
                              LanguageLabelKeys.noReturnRequestsDesc,
                            ),
                            itemBuilder: (context, order, index) =>
                                ReturnOrderCard(
                              order: order,
                              onTap: () => AppNavigator.pushNamed(
                                context,
                                RouteNames.returnOrderDetail,
                                arguments: order.id,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _OrderTypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OrderTypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ThemeConstants.paddingL,
          vertical: ThemeConstants.paddingS,
        ),
        decoration: AppDecorations.card(
          color: selected ? context.cs.primary : context.cs.surfaceContainerLow,
          borderRadius: AppRadius.r20,
          border: Border.all(
            color: selected
                ? context.cs.primary
                : context.cs.outline.withValues(alpha: 0.4),
          ),
        ),
        child: AppText(
          label,
          style: context.tt.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: selected
                ? context.cs.onPrimary
                : context.cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
