import 'package:deliveryboy/utils/extensions/num_extensions.dart';

class Timeline {
  int? status;
  String? statusName;
  String? datetime;
  bool? isDone;
  bool? isCurrent;

  Timeline({
    this.status,
    this.statusName,
    this.datetime,
    this.isDone,
    this.isCurrent,
  });

  Timeline.fromJson(Map<String, dynamic> json) {
    status = toSafeIntOrNull(json['status']);
    statusName = json['status_name']?.toString();
    datetime = json['datetime']?.toString();
    isDone = toSafeBoolOrNull(json['is_done']);
    isCurrent = toSafeBoolOrNull(json['is_current']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['status_name'] = statusName;
    data['datetime'] = datetime;
    data['is_done'] = isDone;
    data['is_current'] = isCurrent;
    return data;
  }
}
