import 'package:customer/utils/json_parsers.dart';

class ServiceabilityModel {
  bool? checked;
  bool? serviceable;
  bool? courierServiceable;
  String? pincode;
  int? zoneId;
  num? charge;
  int? etaDays;
  String? etaText;
  bool? codAvailable;
  String? message;

  ServiceabilityModel({
    this.checked,
    this.serviceable,
    this.courierServiceable,
    this.pincode,
    this.zoneId,
    this.charge,
    this.etaDays,
    this.etaText,
    this.codAvailable,
    this.message,
  });

  ServiceabilityModel.fromJson(Map<String, dynamic> root) {
    // Fields may be flat or wrapped inside `data`.
    final nested = root['data'];
    final json = nested is Map<String, dynamic> ? nested : root;
    checked = parseBool(json['checked']);
    serviceable = parseBool(json['serviceable']);
    courierServiceable = parseBool(json['courier_serviceable']);
    pincode = parseString(json['pincode']);
    zoneId = parseInt(json['zone_id']);
    charge = parseNum(json['charge']);
    etaDays = parseInt(json['eta_days']);
    etaText = parseString(json['eta_text']);
    codAvailable = parseBool(json['cod_available']);
    message = parseString(json['message'] ?? root['message']);
  }

  Map<String, dynamic> toJson() => {
    'checked': checked,
    'serviceable': serviceable,
    'courier_serviceable': courierServiceable,
    'pincode': pincode,
    'zone_id': zoneId,
    'charge': charge,
    'eta_days': etaDays,
    'eta_text': etaText,
    'cod_available': codAvailable,
    'message': message,
  };
}
