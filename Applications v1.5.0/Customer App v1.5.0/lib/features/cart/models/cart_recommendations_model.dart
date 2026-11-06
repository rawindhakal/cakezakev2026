import 'package:customer/features/products/models/product_model.dart';
import 'package:customer/utils/json_parsers.dart';

class CartRecommendations {
  int? status;
  String? message;
  CartRecommendationsData? data;

  CartRecommendations({this.status, this.message, this.data});

  CartRecommendations.fromJson(Map<String, dynamic> json) {
    status = parseInt(json['status']);
    message = parseString(json['message']);
    data = json['data'] is Map<String, dynamic>
        ? CartRecommendationsData.fromJson(json['data'] as Map<String, dynamic>)
        : null;
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'message': message,
    'data': data?.toJson(),
  };
}

class CartRecommendationsData {
  CartRecommendationBlock? crossSell;
  CartRecommendationBlock? upsell;

  CartRecommendationsData({this.crossSell, this.upsell});

  CartRecommendationsData.fromJson(Map<String, dynamic> json) {
    crossSell = json['cross_sell'] is Map<String, dynamic>
        ? CartRecommendationBlock.fromJson(
            json['cross_sell'] as Map<String, dynamic>,
          )
        : null;
    upsell = json['upsell'] is Map<String, dynamic>
        ? CartRecommendationBlock.fromJson(
            json['upsell'] as Map<String, dynamic>,
          )
        : null;
  }

  Map<String, dynamic> toJson() => {
    'cross_sell': crossSell?.toJson(),
    'upsell': upsell?.toJson(),
  };
}

class CartRecommendationBlock {
  List<ProductDataModel>? products;
  int? total;
  int? limit;
  int? offset;

  CartRecommendationBlock({this.products, this.total, this.limit, this.offset});

  CartRecommendationBlock.fromJson(Map<String, dynamic> json) {
    products = json['products'] is List
        ? (json['products'] as List)
              .map((v) => ProductDataModel.fromJson(v as Map<String, dynamic>))
              .toList()
        : <ProductDataModel>[];
    total = parseInt(json['total']);
    limit = parseInt(json['limit']);
    offset = parseInt(json['offset']);
  }

  Map<String, dynamic> toJson() => {
    'products': products?.map((v) => v.toJson()).toList(),
    'total': total,
    'limit': limit,
    'offset': offset,
  };
}
