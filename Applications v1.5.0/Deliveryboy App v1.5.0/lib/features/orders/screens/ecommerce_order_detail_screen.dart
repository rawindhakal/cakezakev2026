import 'package:deliveryboy/commons/cubit/connectivity_cubit.dart';
import 'package:deliveryboy/commons/widgets/app_scaffold.dart';
import 'package:deliveryboy/commons/widgets/custom_app_bar.dart';
import 'package:deliveryboy/commons/widgets/empty_state_widget.dart';
import 'package:deliveryboy/core/constants/theme_constants.dart';
import 'package:deliveryboy/features/orders/widgets/order_skeletons.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/constants/navigation_service.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/routes/route_names.dart';
import 'package:deliveryboy/core/theme/app_spacing.dart';
import 'package:deliveryboy/features/chat/models/chat_message.dart';
import 'package:deliveryboy/features/chat/services/chat_conversation_resolver.dart';
import 'package:deliveryboy/utils/extensions/context_extensions.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/utils/extensions/size_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/ecommerce_order_detail_cubit.dart';
import '../models/ecommerce_order_model.dart';
import '../widgets/order_appbar_title.dart';
import '../widgets/ecommerce_order_detail_items_card.dart';
import '../widgets/bill_summary_card.dart';
import '../widgets/pickup_delivery_card.dart';
import '../widgets/order_timeline_card.dart';
import '../widgets/order_note_card.dart';
import '../widgets/order_refund_card.dart';
import 'package:deliveryboy/utils/extensions/string_extensions.dart';
import '../widgets/order_status_slide_bar.dart';

/// Route args accepted by [EcommerceOrderDetailScreen]: either the order
/// item id (normal navigation, fetched via API) or an already-fetched
/// [EcommerceOrderDataModel] — e.g. from [OrderScannerScreen], which
/// resolves the scan API's response itself and hands it straight to the
/// cubit, skipping a redundant order-detail API call.
String _orderItemIdFromArgs(BuildContext context) {
  final args = ModalRoute.of(context)?.settings.arguments;
  if (args is EcommerceOrderDataModel) return args.id?.toString() ?? '';
  return args as String? ?? '';
}

/// Detail screen for a single ecommerce order, keyed by the ID passed as route args.
class EcommerceOrderDetailScreen extends StatefulWidget {
  const EcommerceOrderDetailScreen({super.key});

  @override
  State<EcommerceOrderDetailScreen> createState() =>
      _EcommerceOrderDetailScreenState();
}

class _EcommerceOrderDetailScreenState
    extends State<EcommerceOrderDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    return BlocProvider(
      create: (_) {
        final cubit = EcommerceOrderDetailCubit();
        if (args is EcommerceOrderDataModel) {
          cubit.loadFromData(args);
        } else {
          cubit.loadOrderDetail(args as String? ?? '');
        }
        return cubit;
      },
      child: const _EcommerceOrderDetailView(),
    );
  }
}

class _EcommerceOrderDetailView extends StatelessWidget {
  const _EcommerceOrderDetailView();

  @override
  Widget build(BuildContext context) {
    // No full-screen offline gate here: the error branch below already renders
    // an app bar + Retry with ApiException's "no internet connection" message.
    // This listener just adds recovery without a manual tap.
    return BlocListener<ConnectivityCubit, ConnectivityState>(
      listener: (context, state) {
        if (state is ConnectivityConnected) {
          context.read<EcommerceOrderDetailCubit>().loadOrderDetail(
            _orderItemIdFromArgs(context),
          );
        }
      },
      child: AppScaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        applyBottomInset: false,
        body: BlocBuilder<EcommerceOrderDetailCubit, EcommerceOrderDetailState>(
          builder: (context, state) {
            if (state is EcommerceOrderDetailLoading) {
              return AppScaffold(
                appBar: CustomAppBar(
                  title: context.translate(LanguageLabelKeys.orderDetail),
                ),
                body: const OrderDetailSkeleton(),
              );
            }
            if (state is EcommerceOrderDetailError) {
              return AppScaffold(
                appBar: CustomAppBar(
                  title: context.translate(LanguageLabelKeys.orderDetail),
                  backgroundColor: context.cs.primary,
                  foregroundColor: context.cs.onPrimary,
                ),
                body: EmptyStateWidget(
                  imagePath: AssetsConstants.noOrderFound,
                  title: state.message,
                  subtitle: context.translate(
                    LanguageLabelKeys.pullDownToRefresh,
                  ),
                  onRetry: () {
                    context.read<EcommerceOrderDetailCubit>().loadOrderDetail(
                      _orderItemIdFromArgs(context),
                    );
                  },
                ),
              );
            }
            if (state is EcommerceOrderDetailLoaded) {
              return _EcommerceOrderDetailBody(order: state.data);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class _EcommerceOrderDetailBody extends StatefulWidget {
  final EcommerceOrderDataModel order;
  const _EcommerceOrderDetailBody({required this.order});

  @override
  State<_EcommerceOrderDetailBody> createState() =>
      _EcommerceOrderDetailBodyState();
}

class _EcommerceOrderDetailBodyState extends State<_EcommerceOrderDetailBody> {
  final _scrollController = ScrollController();

  static const _hiddenStatuses = [1, 2, 3, 6, 7, 8];
  bool get _hideUpdateStatusButton =>
      _hiddenStatuses.contains(widget.order.activeStatus);

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final symbol = order.currency ?? '';
    final timeline = order.timeline ?? [];
    final bottomPad = _hideUpdateStatusButton ? context.bottomSafePadding : ThemeConstants.paddingL;

    return AppScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      applyBottomInset: false,
      extendBody: false,
      appBar: CustomAppBar(
        titleWidget: OrderAppBarTitle(
          statusLabel: order.orderItemStatus ?? '—',
          idLine: order.orderNumber?.toString() ?? '—',
        ),
        scrollController: _scrollController,
      ),
      body: RefreshIndicator(
        color: context.cs.primary,
        onRefresh: () => context
            .read<EcommerceOrderDetailCubit>()
            .loadOrderDetail((order.id)?.toString() ?? ''),
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsetsDirectional.fromSTEB(ThemeConstants.paddingL, ThemeConstants.paddingL, ThemeConstants.paddingL, bottomPad),
          children: [
            PickupDeliveryCard(
              pickupName: order.storeInfo?.storeName ?? order.storeName,
              pickupAddress: order.storeInfo?.formattedAddress,
              pickupPhone: order.storeInfo?.mobile,
              pickupLatitude: order.storeInfo?.latitude,
              pickupLongitude: order.storeInfo?.longitude,
              deliveryName: order.addressInfo?.name,
              deliveryAddress: order.addressInfo?.address ?? order.orderAddress,
              deliveryPhone: order.addressInfo?.mobile ?? order.orderMobile,
              deliveryAlternatePhone: order.addressInfo?.alternateMobile,
              deliveryLatitude: order.addressInfo?.latitude,
              deliveryLongitude: order.addressInfo?.longitude,
              onDeliveryChatTap: order.isDeliveryBoyChatVisible == true
                  ? () async {
                      final orderId =
                          order.orderId?.toString() ??
                          order.id?.toString() ??
                          '';
                      final orderItemId = order.id?.toString();
                      final conversationId = await resolveOrderConversationId(
                        orderId,
                        orderItemId: orderItemId,
                      );
                      if (!context.mounted) return;
                      AppNavigator.pushNamed(
                        context,
                        RouteNames.chat,
                        arguments: ChatScreenArgs(
                          chatType: ChatType.deliveryBoyChat,
                          recipientName:
                              order.addressInfo?.name ??
                              context.translate(LanguageLabelKeys.customer),
                          recipientId: order.userId ?? 0,
                          orderId: orderId,
                          conversationId: conversationId,
                        ),
                      );
                    }
                  : null,
            ),
            if ((order.refundAmount ?? 0) > 0) ...[
              OrderRefundCard(
                refundAmount: order.refundAmount!,
                currency: symbol,
              ),
            ],
            if (order.orderNote.isNotNullOrEmpty) ...[
              AppSpacing.h12,
              OrderNoteCard(note: order.orderNote!),
            ],
            if (timeline.isNotEmpty) ...[
              AppSpacing.h12,
              OrderTimelineCard(timeline: timeline),
            ],
            AppSpacing.h12,
            EcommerceOrderDetailItemsCard(order: order, symbol: symbol),
            AppSpacing.h12,
            BillSummaryCard(
              type: BillOrderType.ecommerce,
              ecommerceOrder: order,
              symbol: symbol,
            ),
          ],
        ),
      ),
      bottomNavigationBar: _hideUpdateStatusButton
          ? null
          : OrderStatusSlideBar.ecommerce(order: order),
    );
  }
}
