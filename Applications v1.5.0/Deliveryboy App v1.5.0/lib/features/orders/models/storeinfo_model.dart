class StoreInfo {
  String? storeName;
  String? latitude;
  String? longitude;
  String? mobile;
  String? formattedAddress;

  StoreInfo({
    this.storeName,
    this.latitude,
    this.longitude,
    this.mobile,
    this.formattedAddress,
  });

  StoreInfo.fromJson(Map<String, dynamic> json) {
    storeName = json['branch_name']?.toString();
    latitude = json['latitude']?.toString();
    longitude = json['longitude']?.toString();
    mobile = json['mobile']?.toString();
    formattedAddress = json['formatted_address']?.toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['branch_name'] = storeName;
    data['latitude'] = latitude;
    data['longitude'] = longitude;
    data['mobile'] = mobile;
    data['formatted_address'] = formattedAddress;
    return data;
  }
}
