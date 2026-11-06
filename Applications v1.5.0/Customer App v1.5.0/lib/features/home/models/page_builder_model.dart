import 'package:customer/features/home/models/home_builder_model.dart';
import 'package:customer/utils/json_parsers.dart';

class PageBuilderModel {
  int? status;
  String? message;
  PageBuilderDataModel? data;

  PageBuilderModel({this.status, this.message, this.data});

  PageBuilderModel.fromJson(Map<String, dynamic> json) {
    status = parseInt(json['status']);
    message = parseString(json['message']);
    data = json['data'] is Map<String, dynamic>
        ? PageBuilderDataModel.fromJson(json['data'] as Map<String, dynamic>)
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

class PageBuilderDataModel {
  Layout? layout;
  int? totalSections;
  PageInfo? page;

  PageBuilderDataModel({this.layout, this.totalSections, this.page});

  PageBuilderDataModel.fromJson(Map<String, dynamic> json) {
    layout = json['layout'] is Map<String, dynamic>
        ? Layout.fromJson(json['layout'] as Map<String, dynamic>)
        : null;
    totalSections = parseInt(json['total_sections']);
    page = json['page'] is Map<String, dynamic>
        ? PageInfo.fromJson(json['page'] as Map<String, dynamic>)
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (layout != null) {
      data['layout'] = layout!.toJson();
    }
    data['total_sections'] = totalSections;
    if (page != null) {
      data['page'] = page!.toJson();
    }
    return data;
  }
}

class PageInfo {
  int? id;
  String? slug;
  String? name;
  String? title;
  String? headerColor;
  String? titleColor;
  List<Sections>? sections;

  PageInfo({
    this.id,
    this.slug,
    this.name,
    this.title,
    this.headerColor,
    this.titleColor,
    this.sections,
  });

  PageInfo.fromJson(Map<String, dynamic> json) {
    id = parseInt(json['id']);
    slug = parseString(json['slug']);
    name = parseString(json['name']);
    title = parseString(json['title']);
    headerColor = parseString(json['header_color']);
    titleColor = parseString(json['title_color']);
    final rawSections = json['sections'];
    if (rawSections is List) {
      sections = rawSections
          .map((v) => Sections.fromJson(v as Map<String, dynamic>))
          .toList();
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['slug'] = slug;
    data['name'] = name;
    data['title'] = title;
    data['header_color'] = headerColor;
    data['title_color'] = titleColor;
    if (sections != null) {
      data['sections'] = sections!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}
