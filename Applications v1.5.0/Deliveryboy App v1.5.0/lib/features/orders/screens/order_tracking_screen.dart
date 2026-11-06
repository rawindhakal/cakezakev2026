import 'dart:async';
import 'package:deliveryboy/commons/cubit/connectivity_cubit.dart';
import 'package:deliveryboy/commons/cubit/settings_cubit.dart';
import 'package:deliveryboy/commons/widgets/app_no_internet_widget.dart';
import 'package:deliveryboy/commons/widgets/app_scaffold.dart';
import 'package:deliveryboy/commons/widgets/custom_app_bar.dart';
import 'package:deliveryboy/core/constants/app_constants.dart';
import 'package:deliveryboy/core/constants/navigation_service.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/core/routes/route_names.dart';
import 'package:deliveryboy/core/utils/app_logger.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/features/chat/models/chat_message.dart';
import 'package:deliveryboy/features/chat/services/chat_conversation_resolver.dart';
import 'package:deliveryboy/features/orders/models/order_status.dart';
import 'package:deliveryboy/features/orders/widgets/order_tracking_map_view.dart';
import 'package:deliveryboy/features/orders/widgets/order_tracking_no_location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:latlong2/latlong.dart';
import '../cubit/order_live_tracking_cubit.dart';

/// Navigation args for [OrderTrackingScreen] — pickup/delivery coordinates and customer info.
class OrderTrackingArgs {
  final double addressLatitude;
  final double addressLongitude;
  final String address;
  final String orderId;
  final String customerName;
  final String customerNumber;
  final String? customerAlternateNumber;
  final int customerId;
  final bool chatVisible;
  final int? orderStatus;
  final double? storeLatitude;
  final double? storeLongitude;
  final String? storeName;
  final String? storeAddress;
  final String? storeNumber;

  const OrderTrackingArgs({
    required this.addressLatitude,
    required this.addressLongitude,
    required this.address,
    required this.orderId,
    required this.customerName,
    required this.customerNumber,
    this.customerAlternateNumber,
    this.customerId = 0,
    this.chatVisible = false,
    this.orderStatus,
    this.storeLatitude,
    this.storeLongitude,
    this.storeName,
    this.storeAddress,
    this.storeNumber,
  });
}

/// Live map screen showing the delivery boy's route to the customer address.
class OrderTrackingScreen extends StatefulWidget {
  final OrderTrackingArgs args;

  const OrderTrackingScreen({super.key, required this.args});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final _mapController = MapController();
  gmap.GoogleMapController? _googleMapController;
  Position? _currentPosition;
  Timer? _trackingTimer;
  bool _permissionDenied = false;
  bool _locationServiceOff = false;
  int? _currentStatus;
  OrderLiveTrackingCubit? _trackingCubit;

  bool get _isGoogle => context.read<SettingsCubit>().isGoogleMapProvider();

  /// Store leg (before pickup) vs customer leg (picked up onward) — mirrors
  /// [OrderStatus.isPrePickup], falling back to the customer destination
  /// when store coordinates aren't available.
  bool get _trackingStore =>
      OrderStatus.isPrePickup(_currentStatus) &&
      widget.args.storeLatitude != null &&
      widget.args.storeLongitude != null;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.args.orderStatus;
    _trackingCubit = context.read<OrderLiveTrackingCubit>()
      ..trackOrder(widget.args.orderId, widget.args.orderStatus);
    _initTracking();
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    // Cached in initState — reading via context.read here is unsafe, the
    // element tree is already deactivated by the time dispose() runs.
    _trackingCubit?.stopTracking();
    super.dispose();
  }

  /// Notification arrived for this order while the screen is open — pull
  /// the fresh status from the cubit and let the map switch legs / start
  /// sending the live-location API if it just became out-for-delivery.
  void _onTrackingCubitState(OrderLiveTrackingState state) {
    if (state is! OrderLiveTrackingLoaded) return;
    final status = context.read<OrderLiveTrackingCubit>().currentOrderStatus;
    if (status != null && status != _currentStatus && mounted) {
      setState(() => _currentStatus = status);
    }
  }

  Future<void> _initTracking() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _locationServiceOff = true);
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _permissionDenied = true);
      return;
    }
    await _fetchAndSend();
    _trackingTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _fetchAndSend(),
    );
  }

  Future<void> _fetchAndSend() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) setState(() => _currentPosition = position);
      await _sendTracking(position);
    } catch (e) {
      logDebug(() => 'OrderTrackingScreen._fetchAndSend failed: $e');
    }
  }

  /// The live-location API is only meant for the customer-facing
  /// out-for-delivery leg — the store leg (before pickup) only needs the
  /// map shown locally, no server ping.
  Future<void> _sendTracking(Position position) async {
    if (_currentStatus != OrderStatus.outForDelivery.id) return;
    try {
      if (mounted) {
        context.read<OrderLiveTrackingCubit>().orderLiveTracking(
          orderId: widget.args.orderId,
          orderStatus: OrderStatus.outForDelivery.value,
          latitude: position.latitude.toString(),
          longitude: position.longitude.toString(),
        );
      }
    } catch (e) {
      logDebug(() => 'OrderTrackingScreen._sendTracking failed: $e');
    }
  }

  Future<void> _chatWithCustomer() async {
    final conversationId = await resolveOrderConversationId(
      widget.args.orderId,
    );
    if (!mounted) return;
    AppNavigator.pushNamed(
      context,
      RouteNames.chat,
      arguments: ChatScreenArgs(
        chatType: ChatType.deliveryBoyChat,
        recipientName: widget.args.customerName,
        recipientId: widget.args.customerId,
        orderId: widget.args.orderId,
        conversationId: conversationId,
      ),
    );
  }

  void _onGoogleMapCreated(gmap.GoogleMapController controller) =>
      _googleMapController = controller;

  void _recenter() {
    final current = _currentPosition;
    if (current == null) return;
    if (_isGoogle) {
      _googleMapController?.animateCamera(
        gmap.CameraUpdate.newLatLngZoom(
          gmap.LatLng(current.latitude, current.longitude),
          15,
        ),
      );
    } else {
      _mapController.move(LatLng(current.latitude, current.longitude), 15);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied || _locationServiceOff) {
      return OrderTrackingNoLocation(
        locationServiceOff: _locationServiceOff,
        onRetry: () {
          setState(() {
            _permissionDenied = false;
            _locationServiceOff = false;
          });
          _initTracking();
        },
      );
    }
    final trackingStore = _trackingStore;
    final destLatLng = trackingStore
        ? LatLng(widget.args.storeLatitude!, widget.args.storeLongitude!)
        : LatLng(widget.args.addressLatitude, widget.args.addressLongitude);
    final currLatLng = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : null;
    return BlocListener<OrderLiveTrackingCubit, OrderLiveTrackingState>(
      listener: (context, state) => _onTrackingCubitState(state),
      child: BlocBuilder<ConnectivityCubit, ConnectivityState>(
        builder: (context, connectivityState) {
          if (connectivityState is ConnectivityDisconnected) {
            // Wrapped in its own scaffold + app bar because the offline state
            // replaces OrderTrackingMapView, which is what owns this route's
            // app bar (and therefore its back button).
            return AppScaffold(
              appBar: CustomAppBar(
                title:
                    '${context.translate(LanguageLabelKeys.trackOrder)} ${AppConstants.hashSymbol}${widget.args.orderId}',
              ),
              body: const AppNoInternetFullScreen(embedded: true),
            );
          }
          return OrderTrackingMapView(
            isGoogle: _isGoogle,
            mapController: _mapController,
            onGoogleMapCreated: _onGoogleMapCreated,
            onRecenter: _recenter,
            destinationLatLng: destLatLng,
            currentLatLng: currLatLng,
            isStoreDestination: trackingStore,
            orderId: widget.args.orderId,
            customerName: trackingStore
                ? (widget.args.storeName ?? '—')
                : widget.args.customerName,
            customerNumber: trackingStore
                ? (widget.args.storeNumber ?? '—')
                : widget.args.customerNumber,
            customerAlternateNumber: trackingStore
                ? null
                : widget.args.customerAlternateNumber,
            address: trackingStore
                ? (widget.args.storeAddress ?? '—')
                : widget.args.address,
            onChatCustomer: !trackingStore && widget.args.chatVisible
                ? _chatWithCustomer
                : null,
          );
        },
      ),
    );
  }
}
