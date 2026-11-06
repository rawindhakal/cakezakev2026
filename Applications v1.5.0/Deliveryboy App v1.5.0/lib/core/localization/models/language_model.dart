/// Generic API response envelope wrapping language-related data.
class LanguageData {
  String? status;
  String? message;
  String? total;
  LanguageData? data;

  LanguageData({this.status, this.message, this.total, this.data});

  LanguageData.fromJson(Map<String, dynamic> json) {
    status = json['status']?.toString();
    message = json['message']?.toString();
    total = json['total']?.toString();
    data = json['data'] != null ? LanguageData.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['message'] = message;
    data['total'] = total;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    return data;
  }
}

/// A single system language entry, including its optional bundled translation JSON.
class LanguageJsonData {
  String? id;
  String? name;
  String? code;
  String? type;
  String? systemType;
  String? isDefault;
  Map<dynamic, dynamic>? jsonData;
  String? systemTypeName;
  String? adminLangIdForFcm;
  String? displayName;

  LanguageJsonData({
    this.id,
    this.name,
    this.code,
    this.type,
    this.systemType,
    this.isDefault,
    this.jsonData,
    this.systemTypeName,
    this.adminLangIdForFcm,
    this.displayName,
  });

  LanguageJsonData.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString();
    name = json['name']?.toString();
    code = json['code']?.toString();
    type = json['type']?.toString();
    systemType = json['system_type']?.toString();
    isDefault = json['is_default']?.toString();
    jsonData = (json['json_data'] != null ? Map.from(json['json_data']) : null);
    systemTypeName = json['system_type_name']?.toString();
    adminLangIdForFcm = json['admin_lang_id_for_fcm']?.toString();
    displayName = json['display_name']?.toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['code'] = code;
    data['type'] = type;
    data['system_type'] = systemType;
    data['is_default'] = isDefault;
    data['system_type_name'] = systemTypeName;
    if (jsonData != null) {
      data['json_data'] = jsonData!;
    }
    data['admin_lang_id_for_fcm'] = adminLangIdForFcm;
    data['display_name'] = displayName;
    return data;
  }
}
