import 'package:latlong2/latlong.dart';

/// Ray-casting point-in-polygon test. `polygon` must be an ordered ring of
/// vertices (need not be explicitly closed). Used to check a picked map
/// point against a zone's `polygon_boundary` locally, without a server call.
bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
  if (polygon.length < 3) return false;
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final xi = polygon[i].longitude;
    final yi = polygon[i].latitude;
    final xj = polygon[j].longitude;
    final yj = polygon[j].latitude;
    final intersect =
        ((yi > point.latitude) != (yj > point.latitude)) &&
        (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi);
    if (intersect) inside = !inside;
  }
  return inside;
}

/// Smallest lat/lng box centred on [center] that still contains every vertex
/// of [polygon]. Fitting the map camera to it frames the whole zone, and
/// because the box is symmetric the camera centre — and so the fixed centre
/// pin — stays on [center] instead of jumping to the polygon's middle.
/// Null when there is no polygon to fit, or when it collapses to a point.
({LatLng southWest, LatLng northEast})? polygonFitBounds(
  LatLng center,
  List<LatLng> polygon,
) {
  if (polygon.length < 3) return null;
  var dLat = 0.0;
  var dLng = 0.0;
  for (final p in polygon) {
    final lat = (p.latitude - center.latitude).abs();
    final lng = (p.longitude - center.longitude).abs();
    if (lat > dLat) dLat = lat;
    if (lng > dLng) dLng = lng;
  }
  if (dLat == 0 && dLng == 0) return null;
  return (
    southWest: LatLng(center.latitude - dLat, center.longitude - dLng),
    northEast: LatLng(center.latitude + dLat, center.longitude + dLng),
  );
}

/// Simple average-of-vertices centroid — good enough to center the map
/// camera on a zone's boundary; not a true polygon centroid for concave
/// shapes, but close enough for that purpose.
LatLng? polygonCentroid(List<LatLng> polygon) {
  if (polygon.isEmpty) return null;
  var lat = 0.0;
  var lng = 0.0;
  for (final p in polygon) {
    lat += p.latitude;
    lng += p.longitude;
  }
  return LatLng(lat / polygon.length, lng / polygon.length);
}
