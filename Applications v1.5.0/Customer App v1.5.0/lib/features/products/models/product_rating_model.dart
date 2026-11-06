class ProductRating {
  String? status;
  String? message;
  String? total;
  ProductRatingData? data;

  ProductRating({this.status, this.message, this.total, this.data});

  ProductRating.fromJson(Map<String, dynamic> json) {
    status = json['status']?.toString() ?? "";
    message = json['message']?.toString() ?? "";
    total = json['total']?.toString() ?? "";
    data = json['data'] != null
        ? ProductRatingData.fromJson(json['data'])
        : null;
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

class ProductRatingData {
  String? averageRating;
  String? oneStarRating;
  String? twoStarRating;
  String? threeStarRating;
  String? fourStarRating;
  String? fiveStarRating;
  List<ProductRatingList>? ratingList;

  ProductRatingData({
    this.averageRating,
    this.oneStarRating,
    this.twoStarRating,
    this.threeStarRating,
    this.fourStarRating,
    this.fiveStarRating,
    this.ratingList,
  });

  ProductRatingData.fromJson(Map<String, dynamic> json) {
    averageRating = json['average_rating']?.toString() ?? "";
    oneStarRating = json['one_star_rating']?.toString() ?? "";
    twoStarRating = json['two_star_rating']?.toString() ?? "";
    threeStarRating = json['three_star_rating']?.toString() ?? "";
    fourStarRating = json['four_star_rating']?.toString() ?? "";
    fiveStarRating = json['five_star_rating']?.toString() ?? "";
    final rawRatingList = json['rating_list'];
    if (rawRatingList is List) {
      ratingList = rawRatingList
          .map((v) => ProductRatingList.fromJson(v as Map<String, dynamic>))
          .toList();
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['average_rating'] = averageRating;
    data['one_star_rating'] = oneStarRating;
    data['two_star_rating'] = twoStarRating;
    data['three_star_rating'] = threeStarRating;
    data['four_star_rating'] = fourStarRating;
    data['five_star_rating'] = fiveStarRating;
    if (ratingList != null) {
      data['rating_list'] = ratingList!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class ProductRatingList {
  String? id;
  String? productId;
  String? userId;
  String? rate;
  String? review;
  String? status;
  String? updatedAt;
  ProductRatingUser? user;
  List<ProductRatingImages>? images;

  ProductRatingList({
    this.id,
    this.productId,
    this.userId,
    this.rate,
    this.review,
    this.status,
    this.updatedAt,
    this.user,
    this.images,
  });

  ProductRatingList.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString() ?? "";
    productId = json['product_id']?.toString() ?? "";
    userId = json['user_id']?.toString() ?? "";
    rate = json['rate']?.toString() ?? "";
    review = json['review']?.toString() ?? "";
    status = json['status']?.toString() ?? "";
    updatedAt = json['updated_at']?.toString() ?? "";
    user = json['user'] != null
        ? ProductRatingUser.fromJson(json['user'])
        : null;
    final rawImages = json['images'];
    if (rawImages is List) {
      images = rawImages
          .map((v) => ProductRatingImages.fromJson(v as Map<String, dynamic>))
          .toList();
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['product_id'] = productId;
    data['user_id'] = userId;
    data['rate'] = rate;
    data['review'] = review;
    data['status'] = status;
    data['updated_at'] = updatedAt;
    if (user != null) {
      data['user'] = user!.toJson();
    }
    if (images != null) {
      data['images'] = images!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class ProductRatingUser {
  String? id;
  String? name;
  String? profile;

  ProductRatingUser({this.id, this.name, this.profile});

  ProductRatingUser.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString() ?? "";
    name = json['name']?.toString() ?? "";
    profile = json['profile']?.toString() ?? "";
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['profile'] = profile;
    return data;
  }
}

class ProductRatingImages {
  String? id;
  String? productRatingId;
  String? image;
  String? imageUrl;

  ProductRatingImages({
    this.id,
    this.productRatingId,
    this.image,
    this.imageUrl,
  });

  ProductRatingImages.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString() ?? "";
    productRatingId = json['product_rating_id']?.toString() ?? "";
    image = json['image']?.toString() ?? "";
    imageUrl = json['image_url']?.toString() ?? "";
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['product_rating_id'] = productRatingId;
    data['image'] = image;
    data['image_url'] = imageUrl;
    return data;
  }
}
