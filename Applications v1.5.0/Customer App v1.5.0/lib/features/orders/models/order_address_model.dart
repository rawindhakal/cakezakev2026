import 'package:customer/utils/json_parsers.dart';

class OrderAddressModel {
  String? name;
  String? address;
  String? mobile;
  String? alternateMobile;
  String? latitude;
  String? longitude;

  /// `0` means billing address differs from this shipping address; `1` means
  /// the order was billed to this same address.
  int? billingSameAsShipping;

  /// Billing address, present when [billingSameAsShipping] is `0`.
  OrderAddressModel? billing;

  OrderAddressModel({
    this.name,
    this.address,
    this.mobile,
    this.alternateMobile,
    this.latitude,
    this.longitude,
    this.billingSameAsShipping,
    this.billing,
  });

  OrderAddressModel.fromJson(Map<String, dynamic> json) {
    name = parseString(json['name']);
    address = parseString(json['address']);
    mobile = parseString(json['mobile']);
    alternateMobile = parseString(json['alternate_mobile']);
    latitude = parseString(json['latitude']);
    longitude = parseString(json['longitude']);
    billingSameAsShipping = parseInt(json['billing_same_as_shipping']);
    billing = json['billing'] is Map<String, dynamic>
        ? OrderAddressModel.fromJson(json['billing'] as Map<String, dynamic>)
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = name;
    data['address'] = address;
    data['mobile'] = mobile;
    data['alternate_mobile'] = alternateMobile;
    data['latitude'] = latitude;
    data['longitude'] = longitude;
    data['billing_same_as_shipping'] = billingSameAsShipping;
    if (billing != null) data['billing'] = billing!.toJson();
    return data;
  }
}
