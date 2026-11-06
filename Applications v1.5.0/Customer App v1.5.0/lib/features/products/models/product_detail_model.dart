import 'package:customer/features/products/models/addon_model.dart';
import 'package:customer/utils/json_parsers.dart';
import 'package:customer/utils/media_type.dart';

class ProductDetailModel {
  int? status;
  String? message;
  ProductDetailDataModel? data;
  int? total;

  ProductDetailModel({this.status, this.message, this.data, this.total});

  ProductDetailModel.fromJson(Map<String, dynamic> json) {
    status = parseInt(json['status']);
    message = parseString(json['message']);
    data = json['data'] is Map<String, dynamic>
        ? ProductDetailDataModel.fromJson(json['data'] as Map<String, dynamic>)
        : null;
    total = parseInt(json['total']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['message'] = message;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    data['total'] = total;
    return data;
  }
}

class ProductDetailDataModel {
  int? id;
  String? name;
  String? slug;
  String? imageUrl;
  List<Images>? images;
  String? shortDescription;
  String? description;
  String? manufacturer;
  String? prescriptionNote;
  bool isPersonalizable = false;
  int? productType;
  String? salesChannel;
  int? isUnlimitedStock;
  int? returnStatus;
  int? returnDays;
  int? cancelableStatus;
  String? tillStatus;
  int? codAllowed;
  int? taxIncludedInPrice;
  String? metaTitle;
  String? metaDescription;
  String? metaKeywords;
  String? schemaMarkup;
  int? categoryId;
  String? categoryName;
  int? brandId;
  String? brandName;
  String? brandImage;
  int? taxId;
  int? taxPercentage;
  String? madeIn;
  bool? isFavorite;
  bool? isDeliverable;
  bool? productRating;

  /// The API sends a fractional average (e.g. `4.5`) — an `int?` field here
  /// threw a TypeError on every product with a non-whole rating.
  double? rating;
  int? ratingCount;
  StarBreakdown? starBreakdown;
  List<VariantAxes>? variantAxes;
  List<Variants>? variants;
  String? tagNames;
  String? branchName;
  String? timeToDeliver;
  int? totalAllowedQuantity;
  String? currency;
  int? decimalPoint;
  String? estimatedDeliveryDate;
  int? pincodeCheckAvailable;

  // Add-on module: `is_food` flags a product that can ask questions;
  // `addon_groups` are those questions for the store the coordinates
  // resolved to. Empty/absent = nothing to ask (also for non-add-on products).
  int? isFood;
  bool? hasAddons;
  List<AddonGroup>? addonGroups;

  bool get isPincodeCheckAvailable => pincodeCheckAvailable == 1;

  /// Add-on module: true when tapping "add" must open the addon sheet.
  bool get requiresAddonSheet =>
      hasAddons == true || (addonGroups?.isNotEmpty ?? false);

  ProductDetailDataModel({
    this.id,
    this.name,
    this.slug,
    this.imageUrl,
    this.images,
    this.shortDescription,
    this.description,
    this.manufacturer,
    this.prescriptionNote,
    this.productType,
    this.salesChannel,
    this.isUnlimitedStock,
    this.returnStatus,
    this.returnDays,
    this.cancelableStatus,
    this.tillStatus,
    this.codAllowed,
    this.taxIncludedInPrice,
    this.metaTitle,
    this.metaDescription,
    this.metaKeywords,
    this.schemaMarkup,
    this.categoryId,
    this.categoryName,
    this.brandId,
    this.brandName,
    this.brandImage,
    this.taxId,
    this.taxPercentage,
    this.madeIn,
    this.isFavorite,
    this.isDeliverable,
    this.productRating,
    this.rating,
    this.ratingCount,
    this.starBreakdown,
    this.variantAxes,
    this.variants,
    this.tagNames,
    this.branchName,
    this.timeToDeliver,
    this.totalAllowedQuantity,
    this.currency,
    this.decimalPoint,
    this.estimatedDeliveryDate,
    this.pincodeCheckAvailable,
    this.isFood,
    this.hasAddons,
    this.addonGroups,
  });

  ProductDetailDataModel.fromJson(Map<String, dynamic> json) {
    id = parseInt(json['id']);
    name = parseString(json['name']);
    slug = parseString(json['slug']);
    imageUrl = parseString(json['image_url']);
    final rawImages = json['images'];
    if (rawImages is List) {
      images = rawImages
          .map((v) => Images.fromJson(v as Map<String, dynamic>))
          .toList();
    }
    shortDescription = parseString(json['short_description']);
    description = parseString(json['description']);
    manufacturer = parseString(json['manufacturer']);
    prescriptionNote = parseString(json['prescription_note']);
    isPersonalizable = '${json['is_personalizable']}' == '1';
    productType = parseInt(json['product_type']);
    salesChannel = parseString(json['sales_channel']);
    isUnlimitedStock = parseInt(json['is_unlimited_stock']);
    returnStatus = parseInt(json['return_status']);
    returnDays = parseInt(json['return_days']);
    cancelableStatus = parseInt(json['cancelable_status']);
    tillStatus = parseString(json['till_status']);
    codAllowed = parseInt(json['cod_allowed']);
    taxIncludedInPrice = parseInt(json['tax_included_in_price']);
    metaTitle = parseString(json['meta_title']);
    metaDescription = parseString(json['meta_description']);
    metaKeywords = parseString(json['meta_keywords']);
    schemaMarkup = parseString(json['schema_markup']);
    categoryId = parseInt(json['category_id']);
    categoryName = parseString(json['category_name']);
    brandId = parseInt(json['brand_id']);
    brandName = parseString(json['brand_name']);
    brandImage = parseString(json['brand_image']);
    taxId = parseInt(json['tax_id']);
    taxPercentage = parseInt(json['tax_percentage']);
    madeIn = parseString(json['made_in']);
    isFavorite = parseBool(json['is_favorite']);
    isDeliverable = parseBool(json['is_deliverable']);
    productRating = parseBool(json['product_rating']);
    rating = parseDoubleOrNull(json['rating']);
    ratingCount = parseInt(json['rating_count']);
    starBreakdown = json['star_breakdown'] != null
        ? StarBreakdown.fromJson(json['star_breakdown'])
        : null;
    final rawVariantAxes = json['variant_axes'];
    if (rawVariantAxes is List) {
      variantAxes = rawVariantAxes
          .map((v) => VariantAxes.fromJson(v as Map<String, dynamic>))
          .toList();
    }
    final rawVariants = json['variants'];
    if (rawVariants is List) {
      variants = rawVariants
          .map((v) => Variants.fromJson(v as Map<String, dynamic>))
          .toList();
    }
    tagNames = parseString(json['tag_names']);
    branchName = parseString(json['branch_name']);
    timeToDeliver = parseString(json['time_to_deliver']);
    totalAllowedQuantity = parseInt(json['total_allowed_quantity']);
    currency = parseString(json['currency']) ?? "";
    decimalPoint = parseInt(json['decimal_point']) ?? 0;
    estimatedDeliveryDate = parseString(json['estimated_delivery_date']);
    pincodeCheckAvailable = parseInt(json['pincode_check_available']) ?? 0;
    // Add-on module.
    isFood = parseInt(json['is_food']) ?? 0;
    hasAddons = parseBool(json['has_addons']);
    final rawAddonGroups = json['addon_groups'];
    if (rawAddonGroups is List) {
      addonGroups = rawAddonGroups
          .whereType<Map<String, dynamic>>()
          .map(AddonGroup.fromJson)
          .toList();
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['slug'] = slug;
    data['image_url'] = imageUrl;
    if (images != null) {
      data['images'] = images!.map((v) => v.toJson()).toList();
    }
    data['short_description'] = shortDescription;
    data['description'] = description;
    data['manufacturer'] = manufacturer;
    data['prescription_note'] = prescriptionNote;
    data['product_type'] = productType;
    data['sales_channel'] = salesChannel;
    data['is_unlimited_stock'] = isUnlimitedStock;
    data['return_status'] = returnStatus;
    data['return_days'] = returnDays;
    data['cancelable_status'] = cancelableStatus;
    data['till_status'] = tillStatus;
    data['cod_allowed'] = codAllowed;
    data['tax_included_in_price'] = taxIncludedInPrice;
    data['meta_title'] = metaTitle;
    data['meta_description'] = metaDescription;
    data['meta_keywords'] = metaKeywords;
    data['schema_markup'] = schemaMarkup;
    data['category_id'] = categoryId;
    data['category_name'] = categoryName;
    data['brand_id'] = brandId;
    data['brand_name'] = brandName;
    data['brand_image'] = brandImage;
    data['tax_id'] = taxId;
    data['tax_percentage'] = taxPercentage;
    data['made_in'] = madeIn;
    data['is_favorite'] = isFavorite;
    data['is_deliverable'] = isDeliverable;
    data['product_rating'] = productRating;
    data['rating'] = rating;
    data['rating_count'] = ratingCount;
    if (starBreakdown != null) {
      data['star_breakdown'] = starBreakdown!.toJson();
    }
    if (variantAxes != null) {
      data['variant_axes'] = variantAxes!.map((v) => v.toJson()).toList();
    }
    if (variants != null) {
      data['variants'] = variants!.map((v) => v.toJson()).toList();
    }
    data['tag_names'] = tagNames;
    data['branch_name'] = branchName;
    data['time_to_deliver'] = timeToDeliver;
    data['total_allowed_quantity'] = totalAllowedQuantity;
    data['currency'] = currency;
    data['decimal_point'] = decimalPoint;
    data['estimated_delivery_date'] = estimatedDeliveryDate;
    data['pincode_check_available'] = pincodeCheckAvailable;
    // Add-on module.
    data['is_food'] = isFood;
    data['has_addons'] = hasAddons;
    if (addonGroups != null) {
      data['addon_groups'] = addonGroups!.map((g) => g.toJson()).toList();
    }
    return data;
  }
}

class StarBreakdown {
  int? i1;
  int? i2;
  int? i3;
  int? i4;
  int? i5;

  StarBreakdown({this.i1, this.i2, this.i3, this.i4, this.i5});

  StarBreakdown.fromJson(Map<String, dynamic> json) {
    i1 = parseInt(json['1']);
    i2 = parseInt(json['2']);
    i3 = parseInt(json['3']);
    i4 = parseInt(json['4']);
    i5 = parseInt(json['5']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['1'] = i1;
    data['2'] = i2;
    data['3'] = i3;
    data['4'] = i4;
    data['5'] = i5;
    return data;
  }
}

class VariantAxes {
  int? attributeId;
  String? attributeName;
  List<Values>? values;

  VariantAxes({this.attributeId, this.attributeName, this.values});

  VariantAxes.fromJson(Map<String, dynamic> json) {
    attributeId = parseInt(json['attribute_id']);
    attributeName = parseString(json['attribute_name']);
    final rawValues = json['values'];
    if (rawValues is List) {
      values = rawValues
          .map((v) => Values.fromJson(v as Map<String, dynamic>))
          .toList();
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['attribute_id'] = attributeId;
    data['attribute_name'] = attributeName;
    if (values != null) {
      data['values'] = values!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Values {
  int? attributeValueId;
  String? attributeValue;

  Values({this.attributeValueId, this.attributeValue});

  Values.fromJson(Map<String, dynamic> json) {
    attributeValueId = parseInt(json['attribute_value_id']);
    attributeValue = parseString(json['attribute_value']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['attribute_value_id'] = attributeValueId;
    data['attribute_value'] = attributeValue;
    return data;
  }
}

class Variants {
  int? id;
  String? name;
  String? sku;
  double? price;
  double? discountedPrice;
  double? discountPercent;
  int? stock;
  bool? inStock;
  bool? isMinAlert;
  int? isUnlimitedStock;
  bool? fewQuantityLeft;
  int? cartCount;
  int? isNotifyRequested;
  List<Images>? images;
  List<Attributes>? attributes;
  List<CustomSections>? customSections;

  Variants({
    this.id,
    this.name,
    this.sku,
    this.price,
    this.discountedPrice,
    this.discountPercent,
    this.stock,
    this.inStock,
    this.isMinAlert,
    this.isUnlimitedStock,
    this.fewQuantityLeft,
    this.cartCount,
    this.isNotifyRequested,
    this.images,
    this.attributes,
    this.customSections,
  });

  bool get isNotified => isNotifyRequested == 1;

  Variants.fromJson(Map<String, dynamic> json) {
    id = parseInt(json['id']);
    name = parseString(json['name']);
    sku = parseString(json['sku']);
    price = parseDouble(json['price']);
    discountedPrice = parseDouble(json['discounted_price']);
    discountPercent = parseDouble(json['discount_percent']);
    stock = parseInt(json['stock']);
    inStock = parseBool(json['in_stock']);
    isMinAlert = parseBool(json['is_min_alert']);
    isUnlimitedStock = parseInt(json['is_unlimited_stock']);
    fewQuantityLeft = parseBool(json['few_quantity_left']);
    cartCount = parseInt(json['cart_count']);
    isNotifyRequested = parseInt(json['is_notify_requested']) ?? 0;
    final rawImages = json['images'];
    if (rawImages is List) {
      images = rawImages
          .map((v) => Images.fromJson(v as Map<String, dynamic>))
          .toList();
    }
    final rawAttributes = json['attributes'];
    if (rawAttributes is List) {
      attributes = rawAttributes
          .map((v) => Attributes.fromJson(v as Map<String, dynamic>))
          .toList();
    }
    final rawCustomSections = json['custom_sections'];
    if (rawCustomSections is List) {
      customSections = rawCustomSections
          .map((v) => CustomSections.fromJson(v as Map<String, dynamic>))
          .toList();
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['sku'] = sku;
    data['price'] = price;
    data['discounted_price'] = discountedPrice;
    data['discount_percent'] = discountPercent;
    data['stock'] = stock;
    data['in_stock'] = inStock;
    data['is_min_alert'] = isMinAlert;
    data['is_unlimited_stock'] = isUnlimitedStock;
    data['few_quantity_left'] = fewQuantityLeft;
    data['cart_count'] = cartCount;
    data['is_notify_requested'] = isNotifyRequested;
    if (images != null) {
      data['images'] = images!.map((v) => v.toJson()).toList();
    }
    if (attributes != null) {
      data['attributes'] = attributes!.map((v) => v.toJson()).toList();
    }
    if (customSections != null) {
      data['custom_sections'] = customSections!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Images {
  String? imageUrl;

  Images({this.imageUrl});

  Images.fromJson(Map<String, dynamic> json) {
    imageUrl = parseString(json['image_url']);
  }

  bool get isVideo => isVideoUrl(imageUrl);

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['image_url'] = imageUrl;
    return data;
  }
}

extension VariantImagesMedia on List<Images> {
  /// First image URL (video only if there is no image) — for thumbnails.
  String? get coverUrl => coverMediaUrl(map((i) => i.imageUrl));
}

class Attributes {
  int? attributeId;
  String? attributeName;
  int? attributeValueId;
  String? attributeValue;

  Attributes({
    this.attributeId,
    this.attributeName,
    this.attributeValueId,
    this.attributeValue,
  });

  Attributes.fromJson(Map<String, dynamic> json) {
    attributeId = parseInt(json['attribute_id']);
    attributeName = parseString(json['attribute_name']);
    attributeValueId = parseInt(json['attribute_value_id']);
    attributeValue = parseString(json['attribute_value']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['attribute_id'] = attributeId;
    data['attribute_name'] = attributeName;
    data['attribute_value_id'] = attributeValueId;
    data['attribute_value'] = attributeValue;
    return data;
  }
}

class CustomSections {
  int? sectionId;
  String? sectionName;
  List<Fields>? fields;

  CustomSections({this.sectionId, this.sectionName, this.fields});

  CustomSections.fromJson(Map<String, dynamic> json) {
    sectionId = parseInt(json['section_id']);
    sectionName = parseString(json['section_name']);
    final rawFields = json['fields'];
    if (rawFields is List) {
      fields = rawFields
          .map((v) => Fields.fromJson(v as Map<String, dynamic>))
          .toList();
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['section_id'] = sectionId;
    data['section_name'] = sectionName;
    if (fields != null) {
      data['fields'] = fields!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Fields {
  String? fieldLabel;
  String? fieldType;
  String? value;

  Fields({this.fieldLabel, this.fieldType, this.value});

  Fields.fromJson(Map<String, dynamic> json) {
    fieldLabel = parseString(json['field_label']);
    fieldType = parseString(json['field_type']);
    value = parseString(json['value']) ?? "";
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['field_label'] = fieldLabel;
    data['field_type'] = fieldType;
    data['value'] = value;
    return data;
  }
}
