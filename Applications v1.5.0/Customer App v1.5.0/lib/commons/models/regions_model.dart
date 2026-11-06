import 'package:customer/utils/json_parsers.dart';

/// API response envelope wrapping the list of [RegionsData] for a country.
class Regions {
  int? status;
  String? message;
  List<RegionsData>? data;
  int? total;

  Regions({this.status, this.message, this.data, this.total});

  Regions.fromJson(Map<String, dynamic> json) {
    status = parseInt(json['status']);
    message = parseString(json['message']);
    final rawData = json['data'];
    if (rawData is List) {
      data = rawData
          .map((v) => RegionsData.fromJson(v as Map<String, dynamic>))
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

/// A single region (state/province) belonging to a country.
class RegionsData {
  int? id;
  int? countryId;
  String? name;

  RegionsData({this.id, this.countryId, this.name});

  RegionsData.fromJson(Map<String, dynamic> json) {
    id = parseInt(json['id']);
    countryId = parseInt(json['country_id']);
    name = parseString(json['name']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['country_id'] = countryId;
    data['name'] = name;
    return data;
  }
}
