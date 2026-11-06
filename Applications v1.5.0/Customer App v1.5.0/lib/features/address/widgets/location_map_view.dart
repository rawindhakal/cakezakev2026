import 'package:customer/core/configs/app_config.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/utils/geo_polygon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:latlong2/latlong.dart';

import 'package:customer/features/address/widgets/pulsing_pin.dart';

class LocationMapView extends StatelessWidget {
  final bool isGoogle;
  final MapController osmController;
  final LatLng pickedPoint;
  final Animation<double> pulseAnimation;
  final void Function(gmap.GoogleMapController) onGoogleMapCreated;
  final void Function(gmap.CameraPosition) onGoogleCameraMove;
  final VoidCallback onGoogleCameraIdle;

  /// Optional delivery-zone boundary to outline on the map (e.g. a zone's
  /// `polygon_boundary`), used only by the zone/location-setup pick flow.
  /// Null/empty draws nothing, so the address add/edit picker — which never
  /// passes this — renders exactly as before.
  final List<LatLng>? boundaryPolygon;
  final Color boundaryColor;
  final Color boundaryFillColor;

  const LocationMapView({
    super.key,
    required this.isGoogle,
    required this.osmController,
    required this.pickedPoint,
    required this.pulseAnimation,
    required this.onGoogleMapCreated,
    required this.onGoogleCameraMove,
    required this.onGoogleCameraIdle,
    this.boundaryPolygon,
    this.boundaryColor = const Color(0xFF2E7D32),
    this.boundaryFillColor = const Color(0x1A2E7D32),
  });

  /// Breathing room left around a fitted boundary, in logical pixels. Kept
  /// public because the Google map has to apply the same fit from the screen
  /// that owns its controller.
  static const double boundaryFitPadding = 48;

  bool get _hasBoundary => (boundaryPolygon?.length ?? 0) >= 3;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: isGoogle ? _buildGoogleMap() : _buildFlutterMap(),
        ),
        IgnorePointer(
          child: Transform.translate(
            offset: const Offset(0, -20),
            child: PulsingPin(animation: pulseAnimation),
          ),
        ),
      ],
    );
  }

  Widget _buildFlutterMap() {
    final fit = polygonFitBounds(pickedPoint, boundaryPolygon ?? const []);
    return FlutterMap(
      mapController: osmController,
      options: MapOptions(
        initialCenter: pickedPoint,
        initialZoom: 13,
        // A zone is rarely the size of one fixed zoom level, so frame the
        // boundary itself and let the zoom fall out of that. Applied once —
        // panning afterwards never re-fits.
        initialCameraFit: fit == null
            ? null
            : CameraFit.bounds(
                bounds: LatLngBounds(fit.southWest, fit.northEast),
                padding: const EdgeInsets.all(boundaryFitPadding),
              ),
      ),
      children: [
        TileLayer(
          urlTemplate: AppConfig.osmMapRenderUrl,
          userAgentPackageName: AppConfig.appPackageName,
          subdomains: AppConstants.osmTileSubdomains,
        ),
        if (_hasBoundary)
          PolygonLayer(
            polygons: [
              Polygon(
                points: boundaryPolygon!,
                color: boundaryFillColor,
                borderColor: boundaryColor,
                borderStrokeWidth: 2,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildGoogleMap() {
    return gmap.GoogleMap(
      initialCameraPosition: gmap.CameraPosition(
        target: gmap.LatLng(pickedPoint.latitude, pickedPoint.longitude),
        zoom: 13,
      ),
      onMapCreated: onGoogleMapCreated,
      onCameraMove: onGoogleCameraMove,
      onCameraIdle: onGoogleCameraIdle,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      polygons: _hasBoundary
          ? {
              gmap.Polygon(
                polygonId: const gmap.PolygonId('zone_boundary'),
                points: boundaryPolygon!
                    .map((p) => gmap.LatLng(p.latitude, p.longitude))
                    .toList(),
                strokeColor: boundaryColor,
                strokeWidth: 2,
                fillColor: boundaryFillColor,
              ),
            }
          : const {},
    );
  }
}
