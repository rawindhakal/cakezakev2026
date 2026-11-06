import 'package:customer/utils/json_parsers.dart';

class BlogCategoryResponse {
  BlogCategoryResponse({this.status, this.message, this.data});

  late final String? status;
  late final String? message;
  late final List<BlogCategory>? data;

  BlogCategoryResponse.fromJson(Map<String, dynamic> json) {
    status = json['status']?.toString();
    message = json['message']?.toString();
    final rawData = json['data'];
    if (rawData is List) {
      data = rawData
          .map((e) => BlogCategory.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      data = [];
    }
  }
}

class BlogCategory {
  String? id;
  String? name;
  String? slug;
  String? metaTitle;
  String? metaKeywords;
  String? metaDescription;
  String? status;
  String? activeBlogsCount;
  String? lang;

  BlogCategory({
    this.id,
    this.name,
    this.slug,
    this.metaTitle,
    this.metaKeywords,
    this.metaDescription,
    this.status,
    this.activeBlogsCount,
    this.lang,
  });

  BlogCategory.fromJson(Map<String, dynamic> json) {
    id = parseString(json['id']) ?? "0";
    name = parseString(json['name']) ?? "";
    slug = parseString(json['slug']) ?? "";
    metaTitle = parseString(json['meta_title']) ?? "";
    metaKeywords = parseString(json['meta_keywords']) ?? "";
    metaDescription = parseString(json['meta_description']) ?? "";
    status = parseString(json['status']) ?? "0";
    activeBlogsCount = parseString(json['active_blogs_count']) ?? "0";
    lang = parseString(json['lang']) ?? "";
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['slug'] = slug;
    data['meta_title'] = metaTitle;
    data['meta_keywords'] = metaKeywords;
    data['meta_description'] = metaDescription;
    data['status'] = status;
    data['active_blogs_count'] = activeBlogsCount;
    return data;
  }
}
