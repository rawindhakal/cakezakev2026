import 'package:customer/utils/json_parsers.dart';

class CategoryResponse {
  String? status;
  String? message;
  String? total;
  List<Category>? data;

  CategoryResponse({this.status, this.message, this.total, this.data});

  CategoryResponse.fromJson(Map<String, dynamic> json) {
    status = json['status']?.toString();
    message = json['message']?.toString();
    total = json['total']?.toString();
    final rawData = json['data'];
    if (rawData is List) {
      data = rawData
          .map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      data = [];
    }
  }
}

class Category {
  String? id;
  String? name;
  String? imageUrl;
  bool? hasChild;
  bool? hasActiveChild;
  String? lang;
  String? subtitle;
  String? metaTitle;
  String? metaKeywords;
  String? schemaMarkup;
  String? metaDescription;

  Category({
    this.id,
    this.name,
    this.imageUrl,
    this.hasChild,
    this.hasActiveChild,
    this.lang,
    this.subtitle,
    this.metaTitle,
    this.metaKeywords,
    this.schemaMarkup,
    this.metaDescription,
  });

  Category.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString() ?? "";
    name = json['name']?.toString() ?? "";
    imageUrl = json['image_url']?.toString() ?? "";
    hasChild = parseBool(json['has_child']) ?? false;
    hasActiveChild = parseBool(json['has_active_child']);
    lang = parseString(json['lang']);
    subtitle = parseString(json['subtitle']);
    metaTitle = parseString(json['meta_title']);
    metaKeywords = parseString(json['meta_keywords']);
    schemaMarkup = parseString(json['schema_markup']);
    metaDescription = parseString(json['meta_description']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['image_url'] = imageUrl;
    data['has_child'] = hasChild;
    data['has_active_child'] = hasActiveChild;
    data['lang'] = lang;
    data['subtitle'] = subtitle;
    data['meta_title'] = metaTitle;
    data['meta_keywords'] = metaKeywords;
    data['schema_markup'] = schemaMarkup;
    data['meta_description'] = metaDescription;
    return data;
  }
}
