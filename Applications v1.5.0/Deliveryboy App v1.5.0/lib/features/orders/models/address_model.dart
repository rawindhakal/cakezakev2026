class Address {
  String? name;
  String? address;
  String? mobile;
  String? alternateMobile;
  String? latitude;
  String? longitude;

  Address({
    this.name,
    this.address,
    this.mobile,
    this.alternateMobile,
    this.latitude,
    this.longitude,
  });

  Address.fromJson(Map<String, dynamic> json) {
    name = json['name']?.toString();
    address = json['address']?.toString();
    mobile = json['mobile']?.toString();
    alternateMobile = json['alternate_mobile']?.toString();
    latitude = json['latitude']?.toString();
    longitude = json['longitude']?.toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = name;
    data['address'] = address;
    data['mobile'] = mobile;
    data['alternate_mobile'] = alternateMobile;
    data['latitude'] = latitude;
    data['longitude'] = longitude;
    return data;
  }
}
