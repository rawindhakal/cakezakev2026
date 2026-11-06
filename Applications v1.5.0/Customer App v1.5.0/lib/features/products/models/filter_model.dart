import 'package:customer/utils/json_parsers.dart';

class FilterModel {
  int? status;
  String? message;
  FilterModelData? data;

  FilterModel({this.status, this.message, this.data});

  FilterModel.fromJson(Map<String, dynamic> json) {
    status = parseInt(json['status']);
    message = parseString(json['message']);
    data = json['data'] is Map<String, dynamic>
        ? FilterModelData.fromJson(json['data'] as Map<String, dynamic>)
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['message'] = message;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    return data;
  }
}

class FilterModelData {
  Category? category;
  List<Category>? childCategories;
  List<Brands>? brands;
  List<Attributes>? attributes;
  num? minPrice;
  num? maxPrice;

  FilterModelData({
    this.category,
    this.childCategories,
    this.brands,
    this.attributes,
    this.minPrice,
    this.maxPrice,
  });

  FilterModelData.fromJson(Map<String, dynamic> json) {
    category = json['category'] is Map<String, dynamic>
        ? Category.fromJson(json['category'] as Map<String, dynamic>)
        : null;
    final rawChildCategories = json['child_categories'];
    if (rawChildCategories is List) {
      childCategories = rawChildCategories
          .map((v) => Category.fromJson(v as Map<String, dynamic>))
          .toList();
    }
    final rawBrands = json['brands'];
    if (rawBrands is List) {
      brands = rawBrands
          .map((v) => Brands.fromJson(v as Map<String, dynamic>))
          .toList();
    }
    final rawAttributes = json['attributes'];
    if (rawAttributes is List) {
      attributes = rawAttributes
          .map((v) => Attributes.fromJson(v as Map<String, dynamic>))
          .toList();
    }
    minPrice = parseNum(json['min_price']);
    maxPrice = parseNum(json['max_price']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (category != null) {
      data['category'] = category!.toJson();
    }
    if (childCategories != null) {
      data['child_categories'] = childCategories!
          .map((v) => v.toJson())
          .toList();
    }
    if (brands != null) {
      data['brands'] = brands!.map((v) => v.toJson()).toList();
    }
    if (attributes != null) {
      data['attributes'] = attributes!.map((v) => v.toJson()).toList();
    }
    data['min_price'] = minPrice;
    data['max_price'] = maxPrice;
    return data;
  }
}

class Category {
  int? id;
  String? name;
  String? slug;
  String? imageUrl;
  bool? hasActiveChild;

  Category({this.id, this.name, this.slug, this.imageUrl, this.hasActiveChild});

  Category.fromJson(Map<String, dynamic> json) {
    id = parseInt(json['id']);
    name = parseString(json['name']);
    slug = parseString(json['slug']);
    imageUrl = parseString(json['image_url']);
    hasActiveChild = parseBool(json['has_active_child']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['slug'] = slug;
    data['image_url'] = imageUrl;
    data['has_active_child'] = hasActiveChild;
    return data;
  }
}

class Brands {
  int? id;
  String? name;
  String? imageUrl;

  Brands({this.id, this.name, this.imageUrl});

  Brands.fromJson(Map<String, dynamic> json) {
    id = parseInt(json['id']);
    name = parseString(json['name']);
    imageUrl = parseString(json['image_url']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['image_url'] = imageUrl;
    return data;
  }
}

class Attributes {
  int? id;
  String? name;
  List<Values>? values;

  Attributes({this.id, this.name, this.values});

  Attributes.fromJson(Map<String, dynamic> json) {
    id = parseInt(json['id']);
    name = parseString(json['name']);
    final rawValues = json['values'];
    if (rawValues is List) {
      values = rawValues
          .map((v) => Values.fromJson(v as Map<String, dynamic>))
          .toList();
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    if (values != null) {
      data['values'] = values!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Values {
  int? id;
  String? value;

  Values({this.id, this.value});

  Values.fromJson(Map<String, dynamic> json) {
    id = parseInt(json['id']);
    value = parseString(json['value']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['value'] = value;
    return data;
  }
}
