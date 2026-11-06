import 'package:deliveryboy/utils/extensions/num_extensions.dart';

/// API response envelope wrapping the list of [ZonesData].
class Zones {
  int? status;
  String? message;
  List<ZonesData>? data;
  int? total;

  Zones({this.status, this.message, this.data, this.total});

  Zones.fromJson(Map<String, dynamic> json) {
    status = toSafeIntOrNull(json['status']);
    message = json['message']?.toString();
    if (json['data'] != null) {
      data = <ZonesData>[];
      json['data'].forEach((v) {
        data!.add(ZonesData.fromJson(v));
      });
    }
    total = toSafeIntOrNull(json['total']);
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

/// A single delivery zone belonging to a country, used by the zone picker.
class ZonesData {
  int? id;
  String? name;

  ZonesData({this.id, this.name});

  ZonesData.fromJson(Map<String, dynamic> json) {
    id = int.tryParse(json['id']?.toString() ?? '');
    name = json['name']?.toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    return data;
  }
}
