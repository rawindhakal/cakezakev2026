import 'package:customer/commons/widgets/app_png_icon.dart';
import 'package:customer/commons/widgets/app_svg_icon.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/constants/assets_constants.dart';
import 'package:customer/core/constants/theme_constants.dart';
import 'package:customer/features/orders/cubit/road_route_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:customer/utils/extensions/size_extensions.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

/// Order tracking map that switches between OSM (flutter_map) and Google Maps
/// based on the app's configured map provider — same switch used on the
/// address picker screen.
class OrderTrackingMapView extends StatefulWidget {
  final bool isGoogle;
  final MapController osmController;
  final void Function(gmap.GoogleMapController) onGoogleMapCreated;
  final LatLng deliveryAddressPoint;
  final LatLng? deliveryBoyPoint;
  final LatLng? storePoint;
  final int? orderId;
  final Color primaryColor;
  final Color onPrimaryColor;

  const OrderTrackingMapView({
    super.key,
    required this.isGoogle,
    required this.osmController,
    required this.onGoogleMapCreated,
    required this.deliveryAddressPoint,
    required this.deliveryBoyPoint,
    this.storePoint,
    required this.orderId,
    required this.primaryColor,
    required this.onPrimaryColor,
  });

  @override
  State<OrderTrackingMapView> createState() => _OrderTrackingMapViewState();
}

class _OrderTrackingMapViewState extends State<OrderTrackingMapView>
    with SingleTickerProviderStateMixin {
  gmap.BitmapDescriptor? _deliveryBoyIcon;
  gmap.BitmapDescriptor? _destinationIcon;
  gmap.BitmapDescriptor? _storeIcon;
  gmap.GoogleMapController? _googleController;

  /// Fit-both-points runs once, the first time a delivery-boy location is
  /// available, so the opening frame already frames boy + destination. Left
  /// alone after that so it never fights the user's own zoom/pan.
  bool _hasFittedBounds = false;

  /// Road-snapped route points from OSRM's free public routing server, used
  /// only for the OSM (flutter_map) tracking view so the line follows actual
  /// roads instead of cutting straight through buildings. The Google view
  /// never fetches this and always shows the direct 2-point line.
  List<LatLng>? _routePoints;

  /// Location the current route was fetched from, so minor GPS jitter
  /// doesn't re-hit the routing server on every location update.
  LatLng? _routedFrom;

  /// Minimum movement (metres) before re-fetching the road route.
  static const double _routeRefreshMeters = 30;

  StreamSubscription<RoadRouteState>? _routeSub;

  /// Rider GPS more than this far off the road route isn't snapped onto it
  /// (route is stale / rider took another road) — drawn at the raw point.
  static const double _snapMaxMeters = 50;

  /// Glides the OSM rider pin from its last shown position to each new poll
  /// position instead of jumping every 15s.
  static const Duration _boyMoveDuration = Duration(milliseconds: 1800);
  late final AnimationController _boyMove = AnimationController(
    vsync: this,
    duration: _boyMoveDuration,
  );
  LatLng? _boyFrom;
  LatLng? _boyTo;

  bool get isGoogle => widget.isGoogle;
  MapController get osmController => widget.osmController;
  void Function(gmap.GoogleMapController) get onGoogleMapCreated =>
      widget.onGoogleMapCreated;
  LatLng get deliveryAddressPoint => widget.deliveryAddressPoint;
  LatLng? get deliveryBoyPoint => widget.deliveryBoyPoint;
  Color get primaryColor => widget.primaryColor;
  Color get onPrimaryColor => widget.onPrimaryColor;

  @override
  void initState() {
    super.initState();
    if (widget.isGoogle) {
      _loadDeliveryBoyIcon();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _captureDestinationIcon(),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => _captureStoreIcon());
    }
    _routeSub = context.read<RoadRouteCubit>().stream.listen((state) {
      if (state is! RoadRouteLoaded || !mounted) return;
      // A slower response for an older rider position — a newer request is
      // already in flight, so don't let this one overwrite it.
      if (state.from != _routedFrom) return;
      if (state.points == null) {
        // OSRM failed — keep the last route (trimmed to the rider below)
        // and clear the anchor so the next poll retries instead of waiting
        // for another 30m of movement.
        _routedFrom = null;
        return;
      }
      setState(() => _routePoints = state.points);
    });
    final origin = widget.deliveryBoyPoint ?? widget.storePoint;
    if (origin != null) {
      _maybeFetchRoute(origin);
    }
  }

  @override
  void dispose() {
    _routeSub?.cancel();
    _boyMove.dispose();
    super.dispose();
  }

  Future<void> _loadDeliveryBoyIcon() async {
    final icon = await gmap.BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(40, 40)),
      AssetsConstants.deliveryBoyTrackingIcon,
    );
    if (mounted) {
      setState(() => _deliveryBoyIcon = icon);
    }
  }

  /// Rasterizes the destination SVG (same asset used for the OSM marker)
  /// straight from its picture data so Google Maps shows the matching pin
  /// instead of its default red marker.
  ///
  /// Previously this snapshotted an offscreen `AppSvgIcon` via
  /// `RepaintBoundary`, but `SvgPicture.asset` decodes asynchronously off
  /// the build phase — the first post-frame callback fired before the
  /// offscreen icon had actually painted, so the capture came out blank and
  /// Google silently fell back to its default pin. Loading the vector
  /// picture directly and drawing it onto our own canvas sidesteps that
  /// widget-paint timing entirely.
  Future<void> _captureDestinationIcon() async {
    final icon = await _rasterizeSvgIcon(
      AssetsConstants.destinationLocationIcon,
    );
    if (icon != null && mounted) setState(() => _destinationIcon = icon);
  }

  /// Same rasterization as [_captureDestinationIcon], for the store pin
  /// shown at [OrderTrackingMapView.storePoint] (mirrors the OSM `AppSvgIcon`
  /// store marker) — Google Maps has no vector-marker support, only bitmaps.
  Future<void> _captureStoreIcon() async {
    final icon = await _rasterizeSvgIcon(AssetsConstants.storePinIcon);
    if (icon != null && mounted) setState(() => _storeIcon = icon);
  }

  /// Rasterizes an svg asset straight from its picture data so Google Maps
  /// shows the matching pin instead of its default red marker.
  ///
  /// Previously this snapshotted an offscreen `AppSvgIcon` via
  /// `RepaintBoundary`, but `SvgPicture.asset` decodes asynchronously off
  /// the build phase — the first post-frame callback fired before the
  /// offscreen icon had actually painted, so the capture came out blank and
  /// Google silently fell back to its default pin. Loading the vector
  /// picture directly and drawing it onto our own canvas sidesteps that
  /// widget-paint timing entirely.
  Future<gmap.BitmapDescriptor?> _rasterizeSvgIcon(String asset) async {
    const displaySize = 35.0;
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final pictureInfo = await vg.loadPicture(SvgAssetLoader(asset), null);
    final targetPx = (displaySize * pixelRatio).round();
    // `BoxFit.contain` (used by AppSvgIcon on the OSM side) auto-centers a
    // non-square viewBox inside its square box; drawing straight onto the
    // canvas doesn't, so a non-square SVG landed in a corner of the bitmap
    // instead of its center — anchor (0.5, 0.5) then pointed at empty
    // padding next to the icon instead of the icon itself.
    final scale =
        targetPx / math.max(pictureInfo.size.width, pictureInfo.size.height);
    final dx = (targetPx - pictureInfo.size.width * scale) / 2;
    final dy = (targetPx - pictureInfo.size.height * scale) / 2;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.translate(dx, dy);
    canvas.scale(scale);
    canvas.drawPicture(pictureInfo.picture);
    final image = await recorder.endRecording().toImage(targetPx, targetPx);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    pictureInfo.picture.dispose();
    if (bytes == null) return null;
    // Without `imagePixelRatio`, Google Maps treats the bitmap's raw pixel
    // count as device-independent pixels — our 2x-supersampled bitmap then
    // rendered at 2x the intended size, and got blurrier still once the
    // device's own screen density stretched it further.
    return gmap.BitmapDescriptor.bytes(
      bytes.buffer.asUint8List(),
      imagePixelRatio: pixelRatio,
    );
  }

  @override
  void didUpdateWidget(covariant OrderTrackingMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_hasFittedBounds &&
        oldWidget.deliveryBoyPoint == null &&
        widget.deliveryBoyPoint != null) {
      _fitBounds();
    }
    _animateBoyTo(oldWidget.deliveryBoyPoint);
    final origin = widget.deliveryBoyPoint ?? widget.storePoint;
    if (origin != null) {
      _maybeFetchRoute(origin);
    }
  }

  /// Rider position to draw this frame — mid-glide between the previous and
  /// latest poll on OSM, the raw latest point on Google.
  LatLng? get _shownBoyPoint {
    final to = _boyTo;
    final from = _boyFrom;
    if (isGoogle || to == null || from == null) return deliveryBoyPoint;
    final t = Curves.easeInOut.transform(_boyMove.value);
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
  }

  void _animateBoyTo(LatLng? previous) {
    final next = widget.deliveryBoyPoint;
    if (isGoogle || next == previous) return;
    if (next == null || previous == null) {
      _boyMove.stop();
      _boyFrom = _boyTo = null;
      return;
    }
    // Start from wherever the pin is right now, so a poll landing
    // mid-glide continues smoothly instead of snapping back.
    _boyFrom = _shownBoyPoint ?? previous;
    _boyTo = next;
    _boyMove.forward(from: 0);
  }

  /// Projects [p] onto the nearest segment of [_routePoints]. Flat-earth
  /// approximation — accurate enough at street scale.
  ({LatLng point, int segment, double meters})? _snapToRoute(LatLng p) {
    final route = _routePoints;
    if (route == null || route.length < 2) return null;
    final cosLat = math.cos(p.latitude * math.pi / 180);
    var best = double.infinity;
    var segment = 0;
    var point = route.first;
    for (var i = 0; i < route.length - 1; i++) {
      final ax = (route[i].longitude - p.longitude) * cosLat;
      final ay = route[i].latitude - p.latitude;
      final dx = (route[i + 1].longitude - route[i].longitude) * cosLat;
      final dy = route[i + 1].latitude - route[i].latitude;
      final len2 = dx * dx + dy * dy;
      final t = len2 == 0 ? 0.0 : (-(ax * dx + ay * dy) / len2).clamp(0.0, 1.0);
      final cx = ax + t * dx;
      final cy = ay + t * dy;
      final d2 = cx * cx + cy * cy;
      if (d2 < best) {
        best = d2;
        segment = i;
        point = LatLng(p.latitude + cy, p.longitude + cx / cosLat);
      }
    }
    // Degrees → metres (~111.32 km per degree of latitude).
    return (point: point, segment: segment, meters: math.sqrt(best) * 111320);
  }

  /// Re-fetches the road route — from the delivery boy once GPS is
  /// available, else from the store as the pre-rider fallback line — only if
  /// [origin] moved far enough since the last fetch, so the free OSRM demo
  /// server isn't hammered on every GPS tick. Google view skips OSRM
  /// entirely and uses the direct line — no third-party routing dependency
  /// needed on that provider.
  void _maybeFetchRoute(LatLng origin) {
    if (isGoogle) return;
    final routedFrom = _routedFrom;
    if (routedFrom != null &&
        Geolocator.distanceBetween(
              routedFrom.latitude,
              routedFrom.longitude,
              origin.latitude,
              origin.longitude,
            ) <
            _routeRefreshMeters) {
      return;
    }
    _routedFrom = origin;
    context.read<RoadRouteCubit>().fetchRoute(origin, deliveryAddressPoint);
  }

  /// Road-snapped points when available, else the direct line as fallback.
  ///
  /// The route is only re-fetched every [_routeRefreshMeters], so between
  /// fetches the rider has already moved past the route's start. Cut the
  /// route at the rider's projection onto it so the already-travelled part
  /// disappears and the line starts exactly where the pin is drawn — the
  /// first point is always the pin position (see [_buildFlutterMap]).
  List<LatLng> _polylinePoints(LatLng origin) {
    final snap = _snapToRoute(origin);
    if (snap == null) return [origin, deliveryAddressPoint];
    return [
      if (snap.meters > _snapMaxMeters) origin,
      snap.point,
      ..._routePoints!.sublist(snap.segment + 1),
    ];
  }

  /// Tracking line to draw right now: the delivery boy's route once GPS is
  /// available, otherwise the store-to-customer route as a pre-rider
  /// fallback so the customer isn't looking at a bare map before the boy's
  /// data arrives. Both are road-snapped on OSM (via [_polylinePoints] /
  /// [_routePoints]) and a direct line on Google, same as the boy line
  /// always was.
  List<LatLng> _currentLinePoints() {
    final origin = _shownBoyPoint ?? widget.storePoint;
    if (origin == null) return const [];
    return _polylinePoints(origin);
  }

  /// Height of the draggable bottom sheet's initial size, reserved as bottom
  /// padding so the fit doesn't tuck either marker behind it.
  double get _bottomSheetReserve => context.screenHeight * 0.42;

  /// Frames both the delivery boy and the destination on screen together,
  /// clear of the bottom sheet.
  void _fitBounds() {
    final boyPoint = widget.deliveryBoyPoint;
    if (boyPoint == null) return;
    _hasFittedBounds = true;
    if (isGoogle) {
      _googleController?.moveCamera(_googleBoundsUpdate(boyPoint));
    } else {
      osmController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds(boyPoint, deliveryAddressPoint),
          padding: EdgeInsets.only(
            top: context.heightFraction(0.074),
            left: context.heightFraction(0.074),
            right: context.heightFraction(0.074),
            bottom: _bottomSheetReserve + context.heightFraction(0.05),
          ),
        ),
      );
    }
  }

  gmap.CameraUpdate _googleBoundsUpdate(LatLng boyPoint) {
    final south = math.min(boyPoint.latitude, deliveryAddressPoint.latitude);
    final north = math.max(boyPoint.latitude, deliveryAddressPoint.latitude);
    final west = math.min(boyPoint.longitude, deliveryAddressPoint.longitude);
    final east = math.max(boyPoint.longitude, deliveryAddressPoint.longitude);
    return gmap.CameraUpdate.newLatLngBounds(
      gmap.LatLngBounds(
        southwest: gmap.LatLng(south, west),
        northeast: gmap.LatLng(north, east),
      ),
      60,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isGoogle) return _buildFlutterMap();
    return _buildGoogleMap();
  }

  /// Compass bearing (degrees, 0-360) from [from] to [to], used to point the
  /// delivery-boy icon along the tracking line toward the destination.
  double _bearingDegrees(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLon = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  /// Heading from the pin along the line — the road direction when snapped,
  /// instead of a straight bearing to the destination.
  double _lineBearing(List<LatLng> line) {
    final from = line.first;
    for (final p in line.skip(1)) {
      if (Geolocator.distanceBetween(
            from.latitude,
            from.longitude,
            p.latitude,
            p.longitude,
          ) >
          1) {
        return _bearingDegrees(from, p);
      }
    }
    return _bearingDegrees(from, deliveryAddressPoint);
  }

  Widget _buildFlutterMap() {
    final boyPoint = deliveryBoyPoint;
    return FlutterMap(
      mapController: osmController,
      options: MapOptions(
        initialCenter: deliveryAddressPoint,
        initialZoom: 17.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapReady: () {
          if (deliveryBoyPoint != null) {
            _fitBounds();
          } else {
            osmController.move(deliveryAddressPoint, 17.0);
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: AppConfig.osmMapRenderUrl,
          userAgentPackageName: AppConfig.appPackageName,
          subdomains: AppConstants.osmTileSubdomains,
        ),
        // Line + rider pin rebuild per animation frame; everything else in
        // the map stays put.
        AnimatedBuilder(
          animation: _boyMove,
          builder: (context, _) {
            final linePoints = _currentLinePoints();
            final hasBoy = boyPoint != null && linePoints.isNotEmpty;
            return Stack(
              fit: StackFit.expand,
              children: [
                if (linePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: linePoints,
                        color: primaryColor.withValues(alpha: 0.6),
                        strokeWidth: 3,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: deliveryAddressPoint,
                      width: 40,
                      height: 40,
                      child: AppSvgIcon(
                        AssetsConstants.destinationLocationIcon,
                        size: ThemeConstants.iconXL,
                      ),
                    ),
                    // Store pin only before the rider is live; once tracking
                    // starts the customer sees just the delivery boy and
                    // their own pin.
                    if (widget.storePoint != null && boyPoint == null)
                      Marker(
                        point: widget.storePoint!,
                        width: 40,
                        height: 40,
                        child: AppSvgIcon(
                          AssetsConstants.storePinIcon,
                          size: ThemeConstants.iconXL,
                        ),
                      ),
                    // Pin sits on the line's first point (rider snapped onto
                    // the road), so pin and line always move together.
                    if (hasBoy)
                      Marker(
                        point: linePoints.first,
                        width: 40,
                        height: 40,
                        // Top-down bike art faces north — turn it to the
                        // road direction so the front leads along the line.
                        child: Transform.rotate(
                          angle: _lineBearing(linePoints) * math.pi / 180,
                          child: AppPngIcon(
                            AssetsConstants.deliveryBoyTrackingIcon,
                            size: ThemeConstants.iconXL,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildGoogleMap() {
    final boyPoint = deliveryBoyPoint;
    final linePoints = _currentLinePoints();
    return gmap.GoogleMap(
      initialCameraPosition: gmap.CameraPosition(
        target: gmap.LatLng(
          deliveryAddressPoint.latitude,
          deliveryAddressPoint.longitude,
        ),
        zoom: 17.0,
      ),
      onMapCreated: (controller) {
        onGoogleMapCreated(controller);
        _googleController = controller;
        if (deliveryBoyPoint != null) {
          _fitBounds();
        } else {
          controller.moveCamera(
            gmap.CameraUpdate.newLatLngZoom(
              gmap.LatLng(
                deliveryAddressPoint.latitude,
                deliveryAddressPoint.longitude,
              ),
              17.0,
            ),
          );
        }
      },
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      padding: EdgeInsets.only(bottom: _bottomSheetReserve),
      markers: {
        gmap.Marker(
          markerId: const gmap.MarkerId('address'),
          position: gmap.LatLng(
            deliveryAddressPoint.latitude,
            deliveryAddressPoint.longitude,
          ),
          anchor: const Offset(0.5, 1.0),
          icon: _destinationIcon ?? gmap.BitmapDescriptor.defaultMarker,
        ),
        if (widget.storePoint != null && boyPoint == null)
          gmap.Marker(
            markerId: const gmap.MarkerId('store'),
            position: gmap.LatLng(
              widget.storePoint!.latitude,
              widget.storePoint!.longitude,
            ),
            anchor: const Offset(0.5, 1.0),
            icon: _storeIcon ?? gmap.BitmapDescriptor.defaultMarker,
          ),
        if (boyPoint != null)
          gmap.Marker(
            markerId: const gmap.MarkerId('delivery_boy'),
            position: gmap.LatLng(boyPoint.latitude, boyPoint.longitude),
            rotation: _bearingDegrees(boyPoint, deliveryAddressPoint),
            flat: true,
            anchor: const Offset(0.5, 0.5),
            icon:
                _deliveryBoyIcon ??
                gmap.BitmapDescriptor.defaultMarkerWithHue(
                  gmap.BitmapDescriptor.hueGreen,
                ),
          ),
      },
      polylines: {
        if (linePoints.isNotEmpty)
          gmap.Polyline(
            polylineId: const gmap.PolylineId('route'),
            points: linePoints
                .map((p) => gmap.LatLng(p.latitude, p.longitude))
                .toList(),
            color: primaryColor.withValues(alpha: 0.6),
            width: 3,
          ),
      },
    );
  }
}
