class OrderStatus {
  String? status;
  String? message;
  String? total;
  List<OrderStatusData>? data;
  List<OrderStatusData>? returnStatuses;

  OrderStatus({
    this.status,
    this.message,
    this.total,
    this.data,
    this.returnStatuses,
  });

  OrderStatus.fromJson(Map<String, dynamic> json) {
    status = json['status']?.toString();
    message = json['message']?.toString();
    total = json['total']?.toString();
    if (json['data'] != null) {
      data = <OrderStatusData>[];
      json['data'].forEach((v) {
        data!.add(OrderStatusData.fromJson(v));
      });
    }
    if (json['return_statuses'] != null) {
      returnStatuses = <OrderStatusData>[];
      json['return_statuses'].forEach((v) {
        returnStatuses!.add(OrderStatusData.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['message'] = message;
    data['total'] = total;
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    if (returnStatuses != null) {
      data['return_statuses'] = returnStatuses!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class OrderStatusData {
  String? id;
  String? status;
  String? statusName;
  String? isDisabled;

  OrderStatusData({this.id, this.status, this.statusName, this.isDisabled});

  OrderStatusData.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString();
    status = json['status']?.toString();
    statusName = json['status_name']?.toString();
    isDisabled = (json['is_disabled'] ?? 0).toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['status'] = status;
    data['status_name'] = statusName;
    data['is_disabled'] = isDisabled;
    return data;
  }
}
