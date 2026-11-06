import 'package:customer/features/notifications/notification/models/enums/notification_type.dart';

class NotificationModel {
  NotificationModel({
    required this.status,
    required this.message,
    required this.total,
    required this.data,
  });

  late final String status;
  late final String message;
  late final String total;
  late final List<NotificationModelData> data;

  NotificationModel.fromJson(Map<String, dynamic> json) {
    status = json['status']?.toString() ?? "";
    message = json['message']?.toString() ?? "";
    total = json['total']?.toString() ?? "";
    final rawData = json['data'];
    data = rawData is List
        ? rawData
              .map(
                (e) =>
                    NotificationModelData.fromJson(e as Map<String, dynamic>),
              )
              .toList()
        : <NotificationModelData>[];
  }

  Map<String, dynamic> toJson() {
    final itemData = <String, dynamic>{};
    itemData['status'] = status;
    itemData['message'] = message;
    itemData['total'] = total;
    itemData['data'] = data.map((e) => e.toJson()).toList();
    return itemData;
  }
}

class NotificationModelData {
  NotificationType get notificationType => NotificationType.fromRaw(type);

  NotificationModelData({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.typeId,
    required this.imageUrl,
    required this.linkUrl,
    required this.dateSent,
    required this.categoryName,
  });

  late final String id;
  late final String title;
  late final String message;
  late final String type;
  late final String typeId;
  late final String imageUrl;
  late final String linkUrl;
  late final String dateSent;
  late final String categoryName;

  NotificationModelData.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString() ?? "";
    title = json['title']?.toString() ?? "";
    message = json['message']?.toString() ?? "";
    type = json['type']?.toString() ?? "";
    typeId = json['type_id']?.toString() ?? "";
    imageUrl = json['image_url']?.toString() ?? "";
    linkUrl = json['link_url']?.toString() ?? "";
    dateSent = json['date_sent']?.toString() ?? '';
    categoryName = json['category_name']?.toString() ?? "";
  }

  Map<String, dynamic> toJson() {
    final itemData = <String, dynamic>{};
    itemData['id'] = id;
    itemData['title'] = title;
    itemData['message'] = message;
    itemData['type'] = type;
    itemData['type_id'] = typeId;
    itemData['image_url'] = imageUrl;
    itemData['link_url'] = linkUrl;
    itemData['date_sent'] = dateSent;
    itemData['category_name'] = categoryName;
    return itemData;
  }
}
