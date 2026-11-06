import 'package:customer/features/blog/models/blog_category_model.dart';
import 'package:customer/utils/json_parsers.dart';

class BlogResponse {
  BlogResponse({this.status, this.message, this.total, this.data});

  late final String? status;
  late final String? message;
  late final String? total;
  late final List<Blog>? data;

  BlogResponse.fromJson(Map<String, dynamic> json) {
    status = json['status']?.toString();
    message = json['message']?.toString();
    total = json['total']?.toString();
    final rawData = json['data'];
    if (rawData is List) {
      data = rawData
          .map((e) => Blog.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      data = [];
    }
  }
}

class Blog {
  String? id;
  String? title;
  String? slug;
  String? categoryId;
  String? image;
  String? description;
  String? shortDescription;
  String? tags;
  List<String>? tagNames;
  String? metaTitle;
  String? metaKeywords;
  String? metaDescription;
  String? status;
  String? imageUrl;
  BlogCategory? category;
  String? viewsCount;
  String? createdAt;
  String? readTime;
  String? lang;

  Blog({
    this.id,
    this.title,
    this.slug,
    this.categoryId,
    this.image,
    this.description,
    this.shortDescription,
    this.tags,
    this.tagNames,
    this.metaTitle,
    this.metaKeywords,
    this.metaDescription,
    this.status,
    this.imageUrl,
    this.category,
    this.viewsCount,
    this.createdAt,
    this.readTime,
  });

  Blog.fromJson(Map<String, dynamic> json) {
    id = parseString(json['id']) ?? "0";
    title = parseString(json['title']) ?? "";
    slug = parseString(json['slug']) ?? "";
    categoryId = parseString(json['category_id']) ?? "0";
    image = parseString(json['image']) ?? "";
    description = parseString(json['description']) ?? "";
    shortDescription = parseString(json['short_description']) ?? "";
    tags = parseString(json['tags']) ?? "";
    tagNames = json['tag_names'] is List
        ? (json['tag_names'] as List).map((e) => e.toString()).toList()
        : <String>[];
    metaTitle = parseString(json['meta_title']) ?? "";
    metaKeywords = parseString(json['meta_keywords']) ?? "";
    metaDescription = parseString(json['meta_description']) ?? "";
    status = parseString(json['status']) ?? "0";
    imageUrl = parseString(json['image_url']) ?? "";
    category = json['category'] is Map<String, dynamic>
        ? BlogCategory.fromJson(json['category'] as Map<String, dynamic>)
        : null;
    viewsCount = parseString(json['views_count']) ?? "0";
    createdAt = parseString(json['created_at']) ?? "";
    readTime = parseString(json['read_time']) ?? "0";
    lang = parseString(json['lang']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['title'] = title;
    data['slug'] = slug;
    data['category_id'] = categoryId;
    data['image'] = image;
    data['description'] = description;
    data['short_description'] = shortDescription;
    data['tags'] = tags;
    data['tag_names'] = tagNames;
    data['meta_title'] = metaTitle;
    data['meta_keywords'] = metaKeywords;
    data['meta_description'] = metaDescription;
    data['status'] = status;
    data['image_url'] = imageUrl;
    if (category != null) {
      data['category'] = category!.toJson();
    }
    data['views_count'] = viewsCount;
    data['created_at'] = createdAt;
    data['read_time'] = readTime;
    data['lang'] = lang;
    return data;
  }
}
