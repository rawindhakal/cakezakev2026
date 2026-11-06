class RatingImages {
  String? status;
  String? message;
  String? total;
  List<String>? data;

  RatingImages({this.status, this.message, this.total, this.data});

  RatingImages.fromJson(Map<String, dynamic> json) {
    status = json['status']?.toString() ?? "";
    message = json['message']?.toString() ?? "";
    total = json['total']?.toString() ?? "";
    final rawData = json['data'];
    data = rawData is List
        ? rawData.map((e) => e.toString()).toList()
        : <String>[];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['message'] = message;
    data['total'] = total;
    data['data'] = this.data;
    return data;
  }
}
