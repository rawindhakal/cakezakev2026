class Address {
  String? status;
  String? message;
  String? total;
  List<AddressData>? data;

  Address({this.status, this.message, this.total, this.data});

  Address.fromJson(Map<String, dynamic> json) {
    status = json['status']?.toString() ?? "";
    message = json['message']?.toString() ?? "";
    total = json['total']?.toString() ?? "";
    final rawData = json['data'];
    if (rawData is List) {
      data = rawData
          .map((v) => AddressData.fromJson(v as Map<String, dynamic>))
          .toList();
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['message'] = message;
    data['total'] = total;
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class AddressData {
  String? id;
  String? type;
  String? name;
  String? mobile;
  String? countryCode;
  String? alternateMobile;
  String? alternateCountryCode;
  String? address;
  String? landmark;
  String? area;
  String? pincode;
  String? cityId;
  String? city;
  String? state;
  String? country;
  String? latitude;
  String? longitude;
  String? isDefault;

  /// Id of the state/region selected via the region dropdown. Only set when
  /// the user picked [state] from that dropdown — omitted from the request
  /// when [state] was typed manually into the free-text fallback field.
  int? regionId;

  /// Present on a `billing_address` payload (order detail apis) — not sent
  /// or expected on the address-book add/edit apis.
  String? regionCode;
  String? regionTaxCode;

  AddressData({
    this.id,
    this.type,
    this.name,
    this.mobile,
    this.countryCode,
    this.alternateMobile,
    this.alternateCountryCode,
    this.address,
    this.landmark,
    this.area,
    this.pincode,
    this.cityId,
    this.city,
    this.state,
    this.country,
    this.latitude,
    this.longitude,
    this.isDefault,
    this.regionId,
    this.regionCode,
    this.regionTaxCode,
  });

  AddressData.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString() ?? "";
    type = json['type']?.toString() ?? "";
    name = json['name']?.toString() ?? "";
    mobile = json['mobile']?.toString() ?? "";
    countryCode = json['country_code']?.toString();
    alternateMobile = json['alternate_mobile']?.toString();
    alternateCountryCode = json['alternate_country_code']?.toString();
    address = json['address']?.toString() ?? "";
    landmark = json['landmark']?.toString();
    area = json['area']?.toString() ?? "";
    pincode = json['pincode']?.toString() ?? "";
    cityId = json['city_id']?.toString() ?? "";
    city = json['city']?.toString() ?? "";
    state = json['state']?.toString() ?? "";
    country = json['country']?.toString() ?? "";
    latitude = json['latitude']?.toString() ?? "0";
    longitude = json['longitude']?.toString() ?? "0";
    isDefault = json['is_default']?.toString() ?? "";
    regionId = int.tryParse(json['region_id']?.toString() ?? '');
    regionCode = json['region_code']?.toString();
    regionTaxCode = json['region_tax_code']?.toString();
  }

  /// Used for parsing round-trips; omits null/empty optional fields to
  /// match what the add/update address API expects.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (id != null && id!.isNotEmpty) data['id'] = id;
    data['name'] = name;
    data['mobile'] = mobile;
    if (countryCode != null && countryCode!.isNotEmpty) {
      data['country_code'] = countryCode;
    }
    // Alternate country code is only meaningful alongside an alternate mobile.
    if (alternateMobile != null && alternateMobile!.trim().isNotEmpty) {
      data['alternate_mobile'] = alternateMobile;
      if (alternateCountryCode != null && alternateCountryCode!.isNotEmpty) {
        data['alternate_country_code'] = alternateCountryCode;
      }
    }
    data['address'] = address;
    if (landmark != null && landmark!.isNotEmpty) data['landmark'] = landmark;
    if (area != null && area!.isNotEmpty) data['area'] = area;
    data['pincode'] = pincode;
    data['city'] = city;
    data['state'] = state;
    if (regionId != null) data['region_id'] = regionId;
    data['country'] = country;
    data['type'] = type;
    data['latitude'] = latitude ?? '0';
    data['longitude'] = longitude ?? '0';
    data['is_default'] = isDefault == '1' ? '1' : '0';
    return data;
  }
}

extension AddressDataFormat on AddressData {
  /// Short, single-line address used in compact tiles/summaries.
  String get formattedAddress => [
    address,
    area,
    city,
    pincode,
  ].where((s) => s != null && s.isNotEmpty && s != 'null').join(', ');
}
