import 'package:customer/utils/json_parsers.dart';

class AppNotificationSettings {
  int? status;
  String? message;
  List<AppNotificationSettingsData>? data;
  int? total;

  AppNotificationSettings({this.status, this.message, this.data, this.total});

  AppNotificationSettings.fromJson(Map<String, dynamic> json) {
    status = parseInt(json['status']);
    message = parseString(json['message']);
    final rawData = json['data'];
    if (rawData is List) {
      data = rawData
          .map(
            (v) =>
                AppNotificationSettingsData.fromJson(v as Map<String, dynamic>),
          )
          .toList();
    }
    total = parseInt(json['total']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['message'] = message;
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    data['total'] = total;
    return data;
  }
}

class AppNotificationSettingsData {
  String? category;
  List<Events>? events;

  AppNotificationSettingsData({this.category, this.events});

  AppNotificationSettingsData.fromJson(Map<String, dynamic> json) {
    category = parseString(json['category']);
    final rawEvents = json['events'];
    if (rawEvents is List) {
      events = rawEvents
          .map((v) => Events.fromJson(v as Map<String, dynamic>))
          .toList();
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['category'] = category;
    if (events != null) {
      data['events'] = events!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Events {
  String? key;
  String? label;
  Channels? channels;

  Events({this.key, this.label, this.channels});

  Events.fromJson(Map<String, dynamic> json) {
    key = parseString(json['key']);
    label = parseString(json['label']);
    channels = json['channels'] is Map<String, dynamic>
        ? Channels.fromJson(json['channels'] as Map<String, dynamic>)
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['key'] = key;
    data['label'] = label;
    if (channels != null) {
      data['channels'] = channels!.toJson();
    }
    return data;
  }
}

class Channels {
  bool? mail;
  bool? push;
  bool? sms;

  Channels({this.mail, this.push, this.sms});

  Channels.fromJson(Map<String, dynamic> json) {
    mail = parseBool(json['mail']);
    push = parseBool(json['push']);
    sms = parseBool(json['sms']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (mail != null) data['mail'] = mail;
    if (push != null) data['push'] = push;
    if (sms != null) data['sms'] = sms;
    return data;
  }
}
