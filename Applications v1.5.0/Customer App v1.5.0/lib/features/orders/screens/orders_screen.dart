import 'package:customer/commons/cubit/base_pagination_cubit.dart';
import 'package:customer/commons/utils/pagination_scroll_controller.dart';
import 'package:customer/commons/widgets/app_button.dart';
import 'package:customer/commons/widgets/app_date_range_picker.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/commons/widgets/app_text.dart';
import 'package:customer/commons/widgets/date_range_filter_field.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/commons/widgets/custom_app_bar.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/commons/widgets/empty_state_widget.dart';
import 'package:customer/commons/widgets/paginated_list_footer.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/orders/widgets/order_list_skeleton_loader.dart';
import 'package:customer/core/routes/order_detail_args.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/core/theme/app_spacing.dart';
import 'package:customer/features/cart/cubit/guest_cart_sync_cubit.dart';
import 'package:customer/features/orders/cubit/completed_ecommerce_order_cubit.dart';
import 'package:customer/features/orders/cubit/completed_order_cubit.dart';
import 'package:customer/features/orders/cubit/ongoing_ecommerce_order_cubit.dart';
import 'package:customer/features/orders/cubit/ongoing_order_cubit.dart';
import 'package:customer/features/orders/models/ecommerce_order_model.dart';
import 'package:customer/features/orders/models/order_model.dart';
import 'package:customer/features/orders/widgets/ecommerce_order_card.dart';
import 'package:customer/features/orders/widgets/order_card.dart';
import 'package:customer/features/products/models/addon_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:customer/core/theme/app_radius.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:customer/commons/animations/slide_animation.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';
import 'package:customer/utils/show_app_bottom_sheet.dart';
import 'package:customer/core/theme/app_decorations.dart';
import 'package:customer/core/constants/theme_constants.dart';

/// Add-on module: an order item's add-on snapshot as the `{id, qty}`
/// answers to re-add it with — without them a dish with a required group is
/// refused.
List<AddonSelection> _reorderAddons(List<CartAddon>? addons) => [
  for (final a in addons ?? const <CartAddon>[]) ?a.toSelection(),
];

/// Re-adds every item from [order] to the cart in one request via the
/// app-wide [GuestCartSyncCubit] (provided in main.dart) — works for both
/// guest and logged-in users since the bulk-add endpoint resolves the cart
/// by device/session, not strictly by auth token.
void _handleReorder(BuildContext context, OrderData order) {
  final plain = <BulkCartItem>[];
  final withAddons = <BulkCartItem>[];

  for (final item in order.items ?? <OrderItems>[]) {
    final variantId = (item.productVariantId ?? item.variantId)?.toString();
    final qty = item.quantity;
    if (variantId == null || variantId.isEmpty || qty == null || qty <= 0) {
      continue;
    }
    final line = BulkCartItem(
      variantId: variantId,
      qty: qty,
      addons: _reorderAddons(item.addons),
    );
    (line.hasAddons ? withAddons : plain).add(line);
  }

  // Add-on module: the server stops at the first refused line, so add-on
  // lines (whose options may since have gone) go after the plain ones.
  final items = [...plain, ...withAddons];
  if (items.isEmpty) return;

  final isQuick = order.channel == AppConstants.quick;
  context.read<GuestCartSyncCubit>().bulkAddItems(
    quickItems: isQuick ? items : const [],
    ecommerceItems: isQuick ? const [] : items,
  );
}

/// Re-adds a single ecommerce order item to the cart.
void _handleReorderEcommerceItem(
  BuildContext context,
  EcommerceOrderDataModel item,
) {
  final variantId = (item.productVariantId ?? item.variantId)?.toString();
  final qty = item.quantity;
  if (variantId == null || variantId.isEmpty || qty == null || qty <= 0) return;

  context.read<GuestCartSyncCubit>().bulkAddItems(
    ecommerceItems: [
      BulkCartItem(
        variantId: variantId,
        qty: qty,
        addons: _reorderAddons(item.addons),
      ),
    ],
  );
}

/// Reorder button visibility follows the store's globally active channel
/// (set via the home-screen quick/ecommerce toggle), not the tab currently
/// viewed — so it only appears on the listing matching the live channel.
bool get _showQuickReorder =>
    SettingsHiveBox.instance.channel == AppConstants.quick;
bool get _showEcommerceReorder =>
    SettingsHiveBox.instance.channel == AppConstants.ecommerce;

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  // Provided app-wide in main.dart (not owned/closed here) — the
  // notification service refetches these directly on "order" pushes even
  // when this screen isn't open, so they must outlive it.
  late final OngoingOrderCubit _ongoingCubit = context
      .read<OngoingOrderCubit>();
  late final CompletedOrderCubit _completedCubit = context
      .read<CompletedOrderCubit>();
  late final OngoingEcommerceOrderCubit _ongoingEcommerceCubit = context
      .read<OngoingEcommerceOrderCubit>();
  late final CompletedEcommerceOrderCubit _completedEcommerceCubit = context
      .read<CompletedEcommerceOrderCubit>();
  String _channel = SettingsHiveBox.instance.channel;
  DateTimeRange? _dateRange;
  final _appBarShadow = ValueNotifier<bool>(false);
  // Cached — Hive returns a new listenable per call, so the same instance
  // is needed to remove the listener.
  final _channelListenable = SettingsHiveBox.instance.channelListenable;

  bool get _isEcommerce => _channel == AppConstants.ecommerce;

  String? get _startDateParam => _dateRange == null
      ? null
      : DateFormat('yyyy-MM-dd').format(_dateRange!.start);
  String? get _endDateParam => _dateRange == null
      ? null
      : DateFormat('yyyy-MM-dd').format(_dateRange!.end);

  @override
  void initState() {
    super.initState();
    _reloadCurrentChannel();
    _channelListenable.addListener(_onChannelChanged);
  }

  @override
  void dispose() {
    _channelListenable.removeListener(_onChannelChanged);
    _appBarShadow.dispose();
    super.dispose();
  }

  /// Home toggle / zone change switched the active channel — reset the
  /// order-type filter to it so history shows that channel's orders.
  void _onChannelChanged() {
    final channel = SettingsHiveBox.instance.channel;
    if (!mounted || channel == _channel) return;
    setState(() => _channel = channel);
    _reloadCurrentChannel();
  }

  void _reloadCurrentChannel() {
    if (!AuthHiveBox.instance.isLoggedIn) return;
    if (_isEcommerce) {
      _ongoingEcommerceCubit.applyFilters(
        EcommerceOrderFilter(
          startDate: _startDateParam,
          endDate: _endDateParam,
        ),
      );
      _completedEcommerceCubit.applyFilters(
        EcommerceOrderFilter(
          startDate: _startDateParam,
          endDate: _endDateParam,
        ),
      );
    } else {
      _ongoingCubit.applyFilters(
        OrderFilter(
          channel: _channel,
          startDate: _startDateParam,
          endDate: _endDateParam,
        ),
      );
      _completedCubit.applyFilters(
        OrderFilter(
          channel: _channel,
          startDate: _startDateParam,
          endDate: _endDateParam,
        ),
      );
    }
  }

  void _applyFilters(String channel, DateTimeRange? dateRange) {
    setState(() {
      _channel = channel;
      _dateRange = dateRange;
    });
    _reloadCurrentChannel();
  }

  void _clearFilters() {
    setState(() {
      _channel = SettingsHiveBox.instance.channel;
      _dateRange = null;
    });
    _reloadCurrentChannel();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<GuestCartSyncCubit, GuestCartSyncState>(
          listener: (context, state) {
            if (state is GuestCartSyncSuccess) {
              AppNavigator.pushNamed(context, RouteNames.checkout);
            } else if (state is GuestCartSyncError) {
              AppSnackBar.show(
                context: context,
                message: state.message,
                type: SnackBarType.error,
              );
            }
          },
        ),
      ],
      child: DefaultTabController(
        length: 2,
        child: AppScaffold(
          applyBottomInset: false,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: CustomAppBar(
            title: context.translate(LanguageLabelKeys.myOrders),
            showBackButton: false,
            shadowListenable: _appBarShadow,
            actions: [
              _OrderChannelFilter(
                selected: _channel,
                dateRange: _dateRange,
                onApply: _applyFilters,
                onClear: _clearFilters,
              ),
            ],
            bottom: const _PillTabBar(),
          ),
          body: TabBarView(
            physics: const NeverScrollableScrollPhysics(),
            children: _isEcommerce
                ? [
                    MultiBlocProvider(
                      providers: [
                        BlocProvider.value(value: _ongoingEcommerceCubit),
                        BlocProvider.value(value: _completedEcommerceCubit),
                      ],
                      child: _OngoingEcommerceOrderList(
                        onScrolledChanged: (v) => _appBarShadow.value = v,
                      ),
                    ),
                    MultiBlocProvider(
                      providers: [
                        BlocProvider.value(value: _ongoingEcommerceCubit),
                        BlocProvider.value(value: _completedEcommerceCubit),
                      ],
                      child: _CompletedEcommerceOrderList(
                        onScrolledChanged: (v) => _appBarShadow.value = v,
                      ),
                    ),
                  ]
                : [
                    MultiBlocProvider(
                      providers: [
                        BlocProvider.value(value: _ongoingCubit),
                        BlocProvider.value(value: _completedCubit),
                      ],
                      child: _OngoingOrderList(
                        onScrolledChanged: (v) => _appBarShadow.value = v,
                      ),
                    ),
                    MultiBlocProvider(
                      providers: [
                        BlocProvider.value(value: _ongoingCubit),
                        BlocProvider.value(value: _completedCubit),
                      ],
                      child: _CompletedOrderList(
                        onScrolledChanged: (v) => _appBarShadow.value = v,
                      ),
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}

class _OrderChannelFilter extends StatelessWidget {
  final String selected;
  final DateTimeRange? dateRange;
  final void Function(String channel, DateTimeRange? dateRange) onApply;
  final VoidCallback onClear;

  const _OrderChannelFilter({
    required this.selected,
    required this.dateRange,
    required this.onApply,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: AppSvgIcon(
        AssetsConstants.filterIcon,
        size: ThemeConstants.iconM,
        color: context.cs.onSurfaceVariant,
      ),
      onPressed: () => _showFilterSheet(context),
    );
  }

  Future<void> _showFilterSheet(BuildContext context) {
    return showAppBottomSheet<void>(
      context,
      title: context.translate(LanguageLabelKeys.filterOrders),
      padding: const EdgeInsetsDirectional.fromSTEB(
        ThemeConstants.paddingXL,
        ThemeConstants.paddingM,
        ThemeConstants.paddingXL,
        ThemeConstants.paddingXXL,
      ),
      builder: (_) => _OrderChannelFilterSheet(
        selected: selected,
        dateRange: dateRange,
        onApply: onApply,
        onClear: onClear,
      ),
    );
  }
}

class _OrderChannelFilterSheet extends StatefulWidget {
  final String selected;
  final DateTimeRange? dateRange;
  final void Function(String channel, DateTimeRange? dateRange) onApply;
  final VoidCallback onClear;

  const _OrderChannelFilterSheet({
    required this.selected,
    required this.dateRange,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_OrderChannelFilterSheet> createState() =>
      _OrderChannelFilterSheetState();
}

class _OrderChannelFilterSheetState extends State<_OrderChannelFilterSheet> {
  late String _tempChannel = widget.selected;
  late DateTimeRange? _tempDateRange = widget.dateRange;

  String? get _tempStartDate => _tempDateRange == null
      ? null
      : DateFormat('yyyy-MM-dd').format(_tempDateRange!.start);
  String? get _tempEndDate => _tempDateRange == null
      ? null
      : DateFormat('yyyy-MM-dd').format(_tempDateRange!.end);

  @override
  Widget build(BuildContext context) {
    final options = <String, String>{
      AppConstants.quick: context.translate(LanguageLabelKeys.filterQuick),
      AppConstants.ecommerce: context.translate(
        LanguageLabelKeys.filterEcommerce,
      ),
    };
    final entries = options.entries.toList();

    return SlideAnimationList(
      crossAxisAlignment: .start,
      children: [
        AppText(
          context.translate(LanguageLabelKeys.orderType),
          style: context.tt.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.cs.onSurfaceVariant,
          ),
        ),
        AppSpacing.h10,
        Row(
          children: [
            for (final entry in entries) ...[
              _OrderTypeChip(
                label: entry.value,
                selected: entry.key == _tempChannel,
                onTap: () => setState(() => _tempChannel = entry.key),
              ),
              if (entry.key != entries.last.key) AppSpacing.w8,
            ],
          ],
        ),
        AppSpacing.h20,
        AppText(
          context.translate(LanguageLabelKeys.dateRange),
          style: context.tt.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.cs.onSurfaceVariant,
          ),
        ),
        AppSpacing.h10,
        DateRangeFilterField(
          startDate: _tempStartDate,
          endDate: _tempEndDate,
          onTap: () async {
            final now = DateTime.now();
            final range = await showAppDateRangePicker(
              context: context,
              firstDate: DateTime(now.year - 5),
              lastDate: now,
              initialDateRange: _tempDateRange,
            );
            if (range == null) return;
            setState(() => _tempDateRange = range);
          },
          onClear: () => setState(() => _tempDateRange = null),
        ),
        AppSpacing.h28,
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: context.translate(LanguageLabelKeys.clear),
                variant: AppButtonVariant.outline,
                height: context.heightFraction(0.05),
                onPressed: () {
                  AppNavigator.pop(context);
                  widget.onClear();
                },
              ),
            ),
            AppSpacing.w12,
            Expanded(
              child: AppButton(
                label: context.translate(LanguageLabelKeys.apply),
                height: context.heightFraction(0.05),
                onPressed: () {
                  AppNavigator.pop(context);
                  widget.onApply(_tempChannel, _tempDateRange);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PillTabBar extends StatelessWidget implements PreferredSizeWidget {
  const _PillTabBar();

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final containerBg = context.cs.surfaceContainer;
    final unselectedColor = context.cs.onSurfaceVariant;
    final primary = context.cs.primary;

    return Container(
      margin: const EdgeInsetsDirectional.fromSTEB(
        ThemeConstants.paddingL,
        ThemeConstants.paddingS,
        ThemeConstants.paddingL,
        ThemeConstants.paddingM,
      ),
      padding: const EdgeInsetsDirectional.all(ThemeConstants.paddingXS),
      decoration: AppDecorations.box(
        color: containerBg,
        borderRadius: AppRadius.r20,
      ),
      child: TabBar(
        indicator: AppDecorations.box(
          borderRadius: AppRadius.r16,
          gradient: LinearGradient(
            colors: [primary, primary.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: EdgeInsetsDirectional.zero,
        dividerColor: Colors.transparent,
        labelColor: context.cs.onPrimary,
        unselectedLabelColor: unselectedColor,
        labelStyle: context.tt.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: context.tt.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        splashBorderRadius: AppRadius.r16,
        tabs: [
          Tab(height: 44, text: context.translate(LanguageLabelKeys.ongoing)),
          Tab(height: 44, text: context.translate(LanguageLabelKeys.completed)),
        ],
      ),
    );
  }
}

/// Loading/error/empty/paginated-list shell shared by all 4 order-listing
/// tabs (quick + ecommerce, ongoing + completed) — they only differ in which
/// cubit feeds them and how each item card is built.
class _PaginatedOrderList<T> extends StatefulWidget {
  final BasePaginationCubit<T> cubit;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String emptyTitle;
  final String emptySubtitle;
  final ValueChanged<bool>? onScrolledChanged;

  const _PaginatedOrderList({
    super.key,
    required this.cubit,
    required this.itemBuilder,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.onScrolledChanged,
  });

  @override
  State<_PaginatedOrderList<T>> createState() => _PaginatedOrderListState<T>();
}

class _PaginatedOrderListState<T> extends State<_PaginatedOrderList<T>> {
  late final _pager = PaginationScrollController(
    onLoadMore: () => widget.cubit.fetchMore(),
  );

  // Card widget per item. Every pagination emit (isFetchingMore on/off, page
  // appended) makes ListView rebuild all live children; handing back the
  // identical widget lets Flutter skip those card subtrees. The cubit keeps
  // item identity across emits, and patched items are new objects, so they
  // still rebuild. Reset whenever the parent rebuilds (new itemBuilder).
  Expando<Widget> _cards = Expando();

  @override
  void initState() {
    super.initState();
    _pager.controller.addListener(_notifyScrolled);
  }

  @override
  void didUpdateWidget(covariant _PaginatedOrderList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _cards = Expando();
  }

  void _notifyScrolled() {
    widget.onScrolledChanged?.call(
      _pager.controller.hasClients && _pager.controller.offset > 0,
    );
  }

  @override
  void dispose() {
    _pager.controller.removeListener(_notifyScrolled);
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BasePaginationCubit<T>, PaginationState<T>>(
      bloc: widget.cubit,
      builder: (context, state) {
        if (state is PaginationLoading<T>) {
          return const OrderListSkeletonLoader();
        }

        if (state is PaginationError<T>) {
          return EmptyStateWidget(
            imagePath: AssetsConstants.noOrderFound,
            title: state.message,
            subtitle: context.translate(LanguageLabelKeys.pullToRefresh),
            onRetry: () => widget.cubit.refresh(),
          );
        }

        if (state is PaginationLoaded<T>) {
          if (state.data.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => widget.cubit.refresh(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  EmptyStateWidget(
                    imagePath: AssetsConstants.noOrderFound,
                    title: widget.emptyTitle,
                    subtitle: widget.emptySubtitle,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => widget.cubit.refresh(),
            child: _pager.attach(
              ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                controller: _pager.controller,
                padding: EdgeInsetsDirectional.fromSTEB(
                  ThemeConstants.paddingL,
                  ThemeConstants.paddingS,
                  ThemeConstants.paddingL,
                  ThemeConstants.paddingL + context.bottomSafePadding,
                ),
                itemCount: state.data.length + (state.isFetchingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == state.data.length) {
                    return PaginatedListFooter(
                      isLoadingMore: state.isFetchingMore,
                      hasMore: state.hasMore,
                      skeletonBuilder: (_) => const OrderListSkeletonLoader(
                        itemCount: 1,
                        shrinkWrap: true,
                      ),
                    );
                  }
                  final item = state.data[index];
                  return _cards[item as Object] ??= widget.itemBuilder(
                    context,
                    item,
                  );
                },
              ),
            ),
          );
        }

        final isLoggedIn = AuthHiveBox.instance.isLoggedIn;
        return EmptyStateWidget(
          imagePath: AssetsConstants.noOrderFound,
          title: isLoggedIn
              ? widget.emptyTitle
              : context.translate(LanguageLabelKeys.notLoggedInOrdersTitle),
          subtitle: isLoggedIn
              ? widget.emptySubtitle
              : context.translate(LanguageLabelKeys.notLoggedInOrdersSubtitle),
          onRetry: isLoggedIn
              ? null
              : () => AppNavigator.pushNamed(context, RouteNames.login),
          retryLabel: isLoggedIn
              ? LanguageLabelKeys.retry
              : LanguageLabelKeys.login,
        );
      },
    );
  }
}

// ── Ongoing ──────────────────────────────────────────────────────────────────

class _OngoingOrderList extends StatelessWidget {
  final ValueChanged<bool>? onScrolledChanged;

  const _OngoingOrderList({this.onScrolledChanged});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OngoingOrderCubit>();
    final completedCubit = context.read<CompletedOrderCubit>();
    return _PaginatedOrderList<OrderData>(
      cubit: cubit,
      onScrolledChanged: onScrolledChanged,
      emptyTitle: context.translate(LanguageLabelKeys.noOngoingOrders),
      emptySubtitle: context.translate(LanguageLabelKeys.noOrdersYet),
      itemBuilder: (context, order) => OrderCard(
        order: order,
        onTap: () async {
          final result = await AppNavigator.pushNamed(
            context,
            RouteNames.orderDetail,
            arguments: OrderDetailArgs(
              orderId: order.id?.toString() ?? '',
              isOngoing: true,
            ),
          );
          if (result is OrderData && context.mounted) {
            cubit.removeOrder(result.id?.toString() ?? '');
            completedCubit.addOrder(result);
          }
        },
        onTrack: () => AppNavigator.pushNamed(
          context,
          RouteNames.orderTracking,
          arguments: order,
        ),
        onReorder: _showQuickReorder
            ? () => _handleReorder(context, order)
            : null,
      ),
    );
  }
}

// ── Completed ────────────────────────────────────────────────────────────────

class _CompletedOrderList extends StatelessWidget {
  final ValueChanged<bool>? onScrolledChanged;

  const _CompletedOrderList({this.onScrolledChanged});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CompletedOrderCubit>();
    return _PaginatedOrderList<OrderData>(
      cubit: cubit,
      onScrolledChanged: onScrolledChanged,
      emptyTitle: context.translate(LanguageLabelKeys.noCompletedOrders),
      emptySubtitle: context.translate(LanguageLabelKeys.noOrdersYet),
      itemBuilder: (context, order) => OrderCard(
        order: order,
        onTap: () async {
          final result = await AppNavigator.pushNamed(
            context,
            RouteNames.orderDetail,
            arguments: OrderDetailArgs(orderId: order.id?.toString() ?? ''),
          );
          // Already in this list — patch (return) rather than add.
          if (result is OrderData && context.mounted) {
            cubit.patchOrder(result);
          }
        },
        onReorder: _showQuickReorder
            ? () => _handleReorder(context, order)
            : null,
      ),
    );
  }
}

// ── Ecommerce: Ongoing ──────────────────────────────────────────────────────

class _OngoingEcommerceOrderList extends StatelessWidget {
  final ValueChanged<bool>? onScrolledChanged;

  const _OngoingEcommerceOrderList({this.onScrolledChanged});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OngoingEcommerceOrderCubit>();
    final completedCubit = context.read<CompletedEcommerceOrderCubit>();
    return _PaginatedOrderList<EcommerceOrderDataModel>(
      cubit: cubit,
      onScrolledChanged: onScrolledChanged,
      emptyTitle: context.translate(LanguageLabelKeys.noOngoingOrders),
      emptySubtitle: context.translate(LanguageLabelKeys.noOrdersYet),
      itemBuilder: (context, item) => EcommerceOrderCard(
        order: item,
        onTap: () async {
          final result = await AppNavigator.pushNamed(
            context,
            RouteNames.ecommerceOrderDetail,
            arguments: EcommerceOrderDetailArgs(
              orderItemId: item.id?.toString() ?? '',
              isOngoing: true,
            ),
          );
          if (result is EcommerceOrderDataModel && context.mounted) {
            cubit.removeOrder(result.id);
            completedCubit.addOrder(result);
          }
        },
        onReorder: _showEcommerceReorder
            ? () => _handleReorderEcommerceItem(context, item)
            : null,
      ),
    );
  }
}

// ── Ecommerce: Completed ────────────────────────────────────────────────────

class _CompletedEcommerceOrderList extends StatelessWidget {
  final ValueChanged<bool>? onScrolledChanged;

  const _CompletedEcommerceOrderList({this.onScrolledChanged});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CompletedEcommerceOrderCubit>();
    return _PaginatedOrderList<EcommerceOrderDataModel>(
      cubit: cubit,
      onScrolledChanged: onScrolledChanged,
      emptyTitle: context.translate(LanguageLabelKeys.noCompletedOrders),
      emptySubtitle: context.translate(LanguageLabelKeys.noOrdersYet),
      itemBuilder: (context, item) => EcommerceOrderCard(
        order: item,
        onTap: () async {
          final result = await AppNavigator.pushNamed(
            context,
            RouteNames.ecommerceOrderDetail,
            arguments: EcommerceOrderDetailArgs(
              orderItemId: item.id?.toString() ?? '',
            ),
          );
          // Already in this list — patch (return) rather than add.
          if (result is EcommerceOrderDataModel && context.mounted) {
            cubit.patchOrder(result);
          }
        },
        onReorder: _showEcommerceReorder
            ? () => _handleReorderEcommerceItem(context, item)
            : null,
      ),
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
        decoration: AppDecorations.box(
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
