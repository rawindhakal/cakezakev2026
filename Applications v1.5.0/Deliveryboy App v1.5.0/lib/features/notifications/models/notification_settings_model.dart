import 'package:deliveryboy/utils/extensions/num_extensions.dart';

/// API response wrapper for notification preferences.
class AppNotificationSettings {
  int? status;
  String? message;
  List<AppNotificationSettingsData>? data;
  int? total;

  AppNotificationSettings({this.status, this.message, this.data, this.total});

  AppNotificationSettings.fromJson(Map<String, dynamic> json) {
    status = toSafeIntOrNull(json['status']);
    message = json['message']?.toString();
    if (json['data'] != null) {
      data = <AppNotificationSettingsData>[];
      json['data'].forEach((v) {
        data!.add(AppNotificationSettingsData.fromJson(v));
      });
    }
    total = toSafeIntOrNull(json['total']);
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

/// One notification category grouping related events.
class AppNotificationSettingsData {
  String? category;
  List<Events>? events;

  AppNotificationSettingsData({this.category, this.events});

  AppNotificationSettingsData.fromJson(Map<String, dynamic> json) {
    category = json['category']?.toString();
    if (json['events'] != null) {
      events = <Events>[];
      json['events'].forEach((v) {
        events!.add(Events.fromJson(v));
      });
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

/// A single notification event with its per-channel preference.
class Events {
  String? key;
  String? label;
  Channels? channels;

  Events({this.key, this.label, this.channels});

  Events.fromJson(Map<String, dynamic> json) {
    key = json['key']?.toString();
    label = json['label']?.toString();
    channels = json['channels'] != null
        ? Channels.fromJson(json['channels'])
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

/// Per-channel on/off state; a null field means the channel is not
/// applicable for that event.
class Channels {
  bool? mail;
  bool? push;
  bool? sms;

  Channels({this.mail, this.push, this.sms});

  Channels.fromJson(Map<String, dynamic> json) {
    mail = toSafeBoolOrNull(json['mail']);
    push = toSafeBoolOrNull(json['push']);
    sms = toSafeBoolOrNull(json['sms']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (mail != null) data['mail'] = mail;
    if (push != null) data['push'] = push;
    if (sms != null) data['sms'] = sms;
    return data;
  }
}
