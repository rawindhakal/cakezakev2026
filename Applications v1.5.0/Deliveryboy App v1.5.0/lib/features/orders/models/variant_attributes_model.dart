class VariantAttributes {
  String? name;
  String? value;

  VariantAttributes({this.name, this.value});

  VariantAttributes.fromJson(Map<String, dynamic> json) {
    name = json['name']?.toString();
    value = json['value']?.toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = name;
    data['value'] = value;
    return data;
  }
}
