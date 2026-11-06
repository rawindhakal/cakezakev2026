import 'dart:async';
import 'package:customer/commons/widgets/app_snack_bar.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/features/address/widgets/location_permission_dialog.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:latlong2/latlong.dart';

/// Shared Google/OSM map-controller plumbing + "use current location" flow
/// for the location-picker screens (delivery-address picker, zone picker).
/// Each screen keeps its own geocode/zone-check glue: pass it as
/// [onCameraIdle] to [initLocationCamera] and as [onLocated] to
/// [useCurrentLocation] rather than duplicating the controller/permission
/// mechanics that are identical across both screens.
mixin LocationCameraMixin<T extends StatefulWidget> on State<T> {
  late final MapController osmMapController;
  gmap.GoogleMapController? googleMapController;
  LatLng? _pendingCameraMove;
  LatLng? _liveGoogleCameraTarget;
  StreamSubscription<MapEvent>? _osmEventSub;
  bool skipNextIdleGeocode = false;
  bool isLocating = false;
  bool _isPermissionDialogShowing = false;

  late final AnimationController pulseCtrl;
  late final Animation<double> pulseAnim;

  void Function(LatLng point)? _onCameraIdle;

  void initLocationCamera(
    TickerProvider vsync, {
    required void Function(LatLng point) onCameraIdle,
  }) {
    _onCameraIdle = onCameraIdle;
    osmMapController = MapController();
    _osmEventSub = osmMapController.mapEventStream.listen((event) {
      if (event is MapEventMoveEnd) _onCameraIdle?.call(event.camera.center);
    });
    pulseCtrl = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    pulseAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: pulseCtrl, curve: Curves.easeOut));
  }

  void disposeLocationCamera() {
    _osmEventSub?.cancel();
    osmMapController.dispose();
    googleMapController?.dispose();
    pulseCtrl.dispose();
  }

  // ── Camera ────────────────────────────────────────────────────────────────

  void moveCamera(LatLng point, {double zoom = 15, required bool isGoogle}) {
    skipNextIdleGeocode = true;
    if (isGoogle) {
      if (googleMapController != null) {
        googleMapController!.animateCamera(
          gmap.CameraUpdate.newCameraPosition(
            gmap.CameraPosition(
              target: gmap.LatLng(point.latitude, point.longitude),
              zoom: zoom,
            ),
          ),
        );
      } else {
        _pendingCameraMove = point;
      }
    } else {
      osmMapController.move(point, zoom);
    }
  }

  /// [onReadyWithoutPendingMove] fires only when there's no queued
  /// pre-controller move to apply — mirrors the zone screen's boundary-fit
  /// call, which should be skipped once a pending move already re-centres it.
  void onGoogleMapCreated(
    gmap.GoogleMapController controller, {
    VoidCallback? onReadyWithoutPendingMove,
  }) {
    googleMapController = controller;
    if (_pendingCameraMove != null) {
      moveCamera(_pendingCameraMove!, isGoogle: true);
      _pendingCameraMove = null;
      return;
    }
    onReadyWithoutPendingMove?.call();
  }

  void onGoogleCameraMove(gmap.CameraPosition position) {
    _liveGoogleCameraTarget = LatLng(
      position.target.latitude,
      position.target.longitude,
    );
  }

  void onGoogleCameraIdle() {
    final target = _liveGoogleCameraTarget;
    if (target != null) _onCameraIdle?.call(target);
  }

  // ── Current location ──────────────────────────────────────────────────────

  /// [onLocated] runs after a fresh position is obtained (and the widget is
  /// still mounted) — do the screen-specific setState/moveCamera/geocode
  /// there instead of duplicating the permission/error-handling shell.
  Future<void> useCurrentLocation({
    required Future<void> Function(LatLng point) onLocated,
  }) async {
    if (isLocating) return;
    isLocating = true; // set synchronously before any await to prevent race
    setState(() {});
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted && !_isPermissionDialogShowing) {
          _isPermissionDialogShowing = true;
          await showLocationPermissionDialog(context);
          _isPermissionDialogShowing = false;
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      await onLocated(LatLng(pos.latitude, pos.longitude));
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context: context,
          message: context.translate(LanguageLabelKeys.unableToGetLocation),
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => isLocating = false);
    }
  }
}
