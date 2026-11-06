class LocationResult {
  final double latitude;
  final double longitude;
  final String city;
  final String state;
  final String country;
  final String pincode;
  final String area;
  final String road;
  final String formattedAddress;

  const LocationResult({
    required this.latitude,
    required this.longitude,
    this.city = '',
    this.state = '',
    this.country = '',
    this.pincode = '',
    this.area = '',
    this.road = '',
    this.formattedAddress = '',
  });
}
