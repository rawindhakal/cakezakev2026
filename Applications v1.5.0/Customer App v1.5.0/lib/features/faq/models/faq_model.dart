class FaqResponse {
  FaqResponse({this.status, this.message, this.total, this.data});

  late final String? status;
  late final String? message;
  late final String? total;
  late final List<FaqData>? data;

  FaqResponse.fromJson(Map<String, dynamic> json) {
    status = json['status']?.toString();
    message = json['message']?.toString();
    total = json['total']?.toString();
    final rawData = json['data'];
    if (rawData is List) {
      data = rawData
          .map((e) => FaqData.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      data = [];
    }
  }
}

class FaqData {
  FaqData({
    required this.id,
    required this.question,
    required this.answer,
    required this.lang,
  });

  late final String id;
  late final String question;
  late final String answer;
  late final String lang;
  bool isExpanded = false;

  FaqData.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString() ?? "";
    question = json['question']?.toString() ?? "";
    answer = json['answer']?.toString() ?? "";
    lang = json['lang']?.toString() ?? "";
    isExpanded = json['is_expanded'] ?? false;
  }

  Map<String, dynamic> toJson() {
    final itemData = <String, dynamic>{};
    itemData['id'] = id;
    itemData['question'] = question;
    itemData['answer'] = answer;
    itemData['lang'] = lang;
    itemData['is_expanded'] = isExpanded;
    return itemData;
  }
}
