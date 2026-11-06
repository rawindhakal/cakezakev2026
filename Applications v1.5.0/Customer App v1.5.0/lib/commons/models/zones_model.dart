import 'package:customer/utils/json_parsers.dart';

/// API response envelope wrapping the list of [ZonesData] for a country.
class Zones {
  int? status;
  String? message;
  List<ZonesData>? data;
  int? total;

  Zones({this.status, this.message, this.data, this.total});

  Zones.fromJson(Map<String, dynamic> json) {
    status = parseInt(json['status']);
    message = parseString(json['message']);
    final rawData = json['data'];
    if (rawData is List) {
      data = rawData
          .map((v) => ZonesData.fromJson(v as Map<String, dynamic>))
          .toList();
    }
    total = parseInt(json['total']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['message'] = message;
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    data['total'] = total;
    return data;
  }
}

/// A single delivery zone belonging to a country.
class ZonesData {
  int? id;
  String? name;
  String? slug;
  String? channel;
  List<ZonePolygonPoint>? polygonBoundary;
  List<ZonePolygonPoint>? polygonBoundaryQuick;
  List<ZonePolygonPoint>? polygonBoundaryEcommerce;

  ZonesData({
    this.id,
    this.name,
    this.slug,
    this.channel,
    this.polygonBoundary,
    this.polygonBoundaryQuick,
    this.polygonBoundaryEcommerce,
  });

  ZonesData.fromJson(Map<String, dynamic> json) {
    id = parseInt(json['id']);
    name = parseString(json['name']);
    slug = parseString(json['slug']);
    channel = parseString(json['channel']);
    polygonBoundary = _parsePolygon(json['polygon_boundary']);
    polygonBoundaryQuick = _parsePolygon(json['polygon_boundary_quick']);
    polygonBoundaryEcommerce = _parsePolygon(
      json['polygon_boundary_ecommerce'],
    );
  }

  static List<ZonePolygonPoint>? _parsePolygon(dynamic raw) {
    if (raw is! List) return null;
    return raw
        .map((v) => ZonePolygonPoint.fromJson(v as Map<String, dynamic>))
        .toList();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['slug'] = slug;
    data['channel'] = channel;
    if (polygonBoundary != null) {
      data['polygon_boundary'] = polygonBoundary!
          .map((v) => v.toJson())
          .toList();
    }
    if (polygonBoundaryQuick != null) {
      data['polygon_boundary_quick'] = polygonBoundaryQuick!
          .map((v) => v.toJson())
          .toList();
    }
    if (polygonBoundaryEcommerce != null) {
      data['polygon_boundary_ecommerce'] = polygonBoundaryEcommerce!
          .map((v) => v.toJson())
          .toList();
    }
    return data;
  }
}

/// A single lat/lng vertex of a zone's delivery-area polygon.
class ZonePolygonPoint {
  double? lat;
  double? lng;

  ZonePolygonPoint({this.lat, this.lng});

  ZonePolygonPoint.fromJson(Map<String, dynamic> json) {
    lat = parseDoubleOrNull(json['lat']);
    lng = parseDoubleOrNull(json['lng']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['lat'] = lat;
    data['lng'] = lng;
    return data;
  }
}
