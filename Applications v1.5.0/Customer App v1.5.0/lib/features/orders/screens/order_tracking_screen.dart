import 'package:customer/commons/models/app_settings_model.dart';
import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/routes/order_detail_args.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/utils/order_status_labels.dart';
import 'package:customer/utils/extensions/string_extensions.dart';
import 'package:customer/features/orders/cubit/order_live_tracking_cubit.dart';
import 'package:customer/features/orders/cubit/order_tracking_detail_cubit.dart';
import 'package:customer/features/orders/cubit/road_route_cubit.dart';
import 'package:customer/features/orders/models/order_model.dart';
import 'package:customer/features/orders/widgets/order_tracking_bottom_sheet.dart';
import 'package:customer/features/orders/widgets/order_tracking_map_view.dart';
import 'package:customer/features/orders/widgets/order_tracking_shared_widgets.dart';
import 'package:customer/features/orders/widgets/order_tracking_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:customer/utils/extensions/context_extensions.dart';
import 'package:customer/commons/widgets/app_scaffold.dart';

class OrderTrackingScreen extends StatefulWidget {
  final OrderData order;

  const OrderTrackingScreen({super.key, required this.order});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  late final MapController _mapController;
  late final LatLng _deliveryAddressPoint;
  late final LatLng? _storePoint;
  late final OrderTrackingDetailCubit _detailCubit;
  late final OrderLiveTrackingCubit _liveTrackingCubit;
  late final RoadRouteCubit _roadRouteCubit;
  LatLng? _deliveryBoyPoint;
  gmap.GoogleMapController? _googleMapController;

  AppSettingsData? get _settings => SettingsHiveBox.instance.getAppSettings();
  bool get _isGoogle => _settings?.mapProvider == AppConstants.mapProvider;

  // Live delivery boy tracking only makes sense while the order is out for delivery (status 5).
  bool get _isOutForDelivery =>
      widget.order.activeStatus == OrderStatus.outForDelivery;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    final lat = double.tryParse(widget.order.address?.latitude ?? '0') ?? 0.0;
    final lng = double.tryParse(widget.order.address?.longitude ?? '0') ?? 0.0;
    _deliveryAddressPoint = LatLng(
      lat == 0.0 ? 20.5937 : lat,
      lng == 0.0 ? 78.9629 : lng,
    );
    _storePoint = _resolveStorePoint(widget.order);

    _detailCubit = OrderTrackingDetailCubit(widget.order);
    _liveTrackingCubit = OrderLiveTrackingCubit();
    _roadRouteCubit = RoadRouteCubit();
    if (_isOutForDelivery && widget.order.id != null) {
      _liveTrackingCubit.startTracking(widget.order.id!.toString());
    }
  }

  /// Store's location from the order's first item — used to draw a
  /// store-to-customer tracking line before a delivery boy is assigned
  /// (live rider GPS only exists once `activeStatus == 5`).
  LatLng? _resolveStorePoint(OrderData order) {
    final items = order.items;
    final item = (items != null && items.isNotEmpty) ? items.first : null;
    final lat = double.tryParse(item?.branchLatitude ?? '');
    final lng = double.tryParse(item?.branchLongitude ?? '');
    if (lat == null || lng == null || (lat == 0 && lng == 0)) return null;
    return LatLng(lat, lng);
  }

  void _onGoogleMapCreated(gmap.GoogleMapController controller) {
    _googleMapController = controller;
  }

  void _recenter() {
    if (_isGoogle) {
      _googleMapController?.animateCamera(
        gmap.CameraUpdate.newLatLngZoom(
          gmap.LatLng(
            _deliveryAddressPoint.latitude,
            _deliveryAddressPoint.longitude,
          ),
          14.0,
        ),
      );
    } else {
      _mapController.move(_deliveryAddressPoint, 14.0);
    }
  }

  @override
  void dispose() {
    _detailCubit.close();
    _liveTrackingCubit.close();
    _roadRouteCubit.close();
    super.dispose();
  }

  /// Called once when the order flips to delivered while this screen is
  /// still open. Hands off to Order Detail — where per-item rating already
  /// lives via the existing [showRateProductSheet] flow, nothing new here —
  /// with every intermediate route cleared behind it except the main/
  /// bottom-nav shell, so a single back tap from there lands on main/home
  /// whether the customer rates or ignores it.
  void _handleDelivered(BuildContext context, OrderData order) {
    final orderId = order.id?.toString();
    if (orderId == null) {
      AppNavigator.popUntil(context, RouteNames.main);
      return;
    }
    AppNavigator.pushNamedAndRemoveUntilRoute(
      context,
      RouteNames.orderDetail,
      RouteNames.main,
      arguments: OrderDetailArgs(orderId: orderId, highlightRating: true),
    );
  }

  Future<void> _callDeliveryBoy() async {
    final number = _detailCubit.state.deliveryBoyMobile;
    if (!number.hasValue) return;
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _detailCubit),
        BlocProvider.value(value: _liveTrackingCubit),
        BlocProvider.value(value: _roadRouteCubit),
      ],
      child: MultiBlocListener(
        listeners: [
          BlocListener<OrderLiveTrackingCubit, OrderLiveTrackingState>(
            listenWhen: (previous, current) =>
                current is! OrderLiveTrackingError ||
                previous is! OrderLiveTrackingError,
            listener: (context, state) {
              if (state is OrderLiveTrackingLoaded && state.location.isValid) {
                final point = LatLng(
                  state.location.latitude!,
                  state.location.longitude!,
                );
                setState(() => _deliveryBoyPoint = point);
              } else if (state is OrderLiveTrackingError) {
                AppSnackBar.show(
                  context: context,
                  message: state.message,
                  type: SnackBarType.error,
                );
              }
            },
          ),
          // A push/refresh-triggered status change can move the order into
          // or out of "out for delivery" while the screen is already open —
          // start/stop live GPS polling right then instead of only checking
          // once at initState. `active_status == 5` remains the sole source
          // of truth for whether the order is out for delivery; the live
          // tracking API is never used to decide this.
          BlocListener<OrderTrackingDetailCubit, OrderData>(
            listenWhen: (previous, current) =>
                previous.activeStatus != current.activeStatus,
            listener: (context, order) {
              if (order.activeStatus == OrderStatus.outForDelivery &&
                  order.id != null) {
                _liveTrackingCubit.startTracking(order.id!.toString());
              } else {
                _liveTrackingCubit.stopTracking();
              }
            },
          ),
          // Order delivered while this screen is still open — nothing left
          // to track, so hand off to Order Detail (rating lives there, per
          // item) instead of leaving the customer stranded on a dead map.
          BlocListener<OrderTrackingDetailCubit, OrderData>(
            listenWhen: (previous, current) =>
                previous.activeStatus != OrderStatus.delivered &&
                current.activeStatus == OrderStatus.delivered,
            listener: (context, order) => _handleDelivered(context, order),
          ),
        ],
        child: BlocBuilder<OrderTrackingDetailCubit, OrderData>(
          builder: (context, order) {
            return AppScaffold(
              // Sheet runs flush to the bottom; the scaffold color (which the
              // system nav bar strip uses) matches the sheet's surface so the
              // two read as one.
              applyBottomInset: false,
              backgroundColor: context.cs.surfaceContainer,
              body: Column(
                children: [
                  BlocBuilder<OrderLiveTrackingCubit, OrderLiveTrackingState>(
                    buildWhen: (previous, current) =>
                        current is OrderLiveTrackingLoaded,
                    builder: (context, liveState) => OrderTrackingTopBar(
                      orderId: order.id,
                      onBack: () => AppNavigator.pop(context),
                      createdAt: order.createdAt,
                      totalDeliverTime: order.totalDeliverTime,
                      liveTimeToDeliver: liveState is OrderLiveTrackingLoaded
                          ? liveState.location.timeToDeliver
                          : null,
                      statusLabel:
                          order.orderStatusName ??
                          OrderStatusLabels.name(context, order.activeStatus),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        OrderTrackingMapView(
                          isGoogle: _isGoogle,
                          osmController: _mapController,
                          onGoogleMapCreated: _onGoogleMapCreated,
                          deliveryAddressPoint: _deliveryAddressPoint,
                          deliveryBoyPoint: _deliveryBoyPoint,
                          storePoint: _storePoint,
                          orderId: order.id,
                          primaryColor: context.cs.primary,
                          onPrimaryColor: context.cs.onPrimary,
                        ),
                        PositionedDirectional(
                          top: 12,
                          end: 12,
                          child: MapButton(
                            onTap: _recenter,
                            child: AppSvgIcon(
                              AssetsConstants.enableLocationIcon,
                              size: ThemeConstants.iconM,
                              color: context.cs.primary,
                            ),
                          ),
                        ),
                        DraggableScrollableSheet(
                          initialChildSize: 0.42,
                          minChildSize: 0.18,
                          maxChildSize: 0.88,
                          snap: true,
                          snapSizes: const [0.18, 0.42, 0.88],
                          builder: (context, scrollController) {
                            return OrderTrackingBottomSheet(
                              order: order,
                              scrollController: scrollController,
                              onCallDeliveryBoy: _callDeliveryBoy,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
