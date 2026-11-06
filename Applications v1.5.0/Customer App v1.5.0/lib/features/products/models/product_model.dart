import 'package:customer/features/orders/models/order_model.dart';
import 'package:customer/features/products/models/addon_model.dart';
import 'package:customer/utils/json_parsers.dart';
import 'package:customer/utils/media_type.dart';

class ProductModel {
  int? status;
  String? message;
  List<ProductDataModel>? data;
  int? total;
  double? totalMinPrice;
  double? totalMaxPrice;
  List<ProductFilterBrand>? brands;

  ProductModel({
    this.status,
    this.message,
    this.data,
    this.total,
    this.totalMinPrice,
    this.totalMaxPrice,
    this.brands,
  });

  ProductModel.fromJson(Map<String, dynamic> json) {
    status = parseInt(json['status']);
    message = parseString(json['message']);
    final rawData = json['data'];
    if (rawData is List) {
      data = rawData
          .map((v) => ProductDataModel.fromJson(v as Map<String, dynamic>))
          .toList();
    }
    total = parseInt(json['total']);
    totalMinPrice = parseDoubleOrNull(json['total_min_price']);
    totalMaxPrice = parseDoubleOrNull(json['total_max_price']);
    final rawBrands = json['brands'];
    if (rawBrands is List) {
      brands = rawBrands
          .map((v) => ProductFilterBrand.fromJson(v as Map<String, dynamic>))
          .toList();
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['message'] = message;
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    data['total'] = total;
    data['total_min_price'] = totalMinPrice;
    data['total_max_price'] = totalMaxPrice;
    if (brands != null) {
      data['brands'] = brands!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class ProductFilterBrand {
  String? id;
  String? name;
  String? imageUrl;

  ProductFilterBrand({this.id, this.name, this.imageUrl});

  ProductFilterBrand.fromJson(Map<String, dynamic> json) {
    id = parseString(json['id']);
    name = parseString(json['name']);
    imageUrl = parseString(json['image_url']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['image_url'] = imageUrl;
    return data;
  }
}

class ProductDataModel {
  int? id;
  String? name;
  String? productName;
  String? slug;
  List<Images>? images;
  String? shortDescription;
  int? productType;
  String? salesChannel;
  int? categoryId;
  String? categoryName;
  int? brandId;
  String? brandName;
  int? isUnlimitedStock;
  bool? inStock;
  bool? isMinAlert;
  bool? isFavorite;
  bool? productRating;
  double? rating;
  int? ratingCount;
  int? variantsCount;
  double? minPrice;
  int? discountPercent;
  int? variantId;
  String? sku;
  double? price;
  double? discountedPrice;
  int? stock;
  int? totalAllowedQuantity;
  List<Variants>? variants;
  String? timeToDeliver;
  String? prescriptionNote;
  bool? isPrescriptionRequired;
  String? currency;
  int? decimalPoint;
  String? slabDiscountMessage;
  String? estimatedDeliveryDate;

  // Add-on module: `has_addons` on product cards (listings, search,
  // home layout, cart lines) decides whether "add" opens the addon sheet.
  // On cart lines, `addons` is the chosen options nested under the dish,
  // `addon_total` is display-only (already inside price/discounted_price —
  // never add it to a total), and `has_unavailable_addons` means checkout
  // will refuse until the line is fixed.
  bool? hasAddons;
  int? isFood;
  List<CartAddon>? addons;
  double? addonTotal;
  int? hasUnavailableAddons;

  /// Add-on module: true when tapping "add" must open the addon sheet.
  bool get requiresAddonSheet => hasAddons == true;

  /// Add-on module: a cart line carrying chosen options. Two such lines
  /// may share one variant id, so they must never be merged by variant.
  bool get isAddonLine => addons?.isNotEmpty ?? false;

  /// Add-on module: the `{id, qty}` list this line was added with.
  List<AddonSelection> get addonSelections => (addons ?? const [])
      .map((a) => a.toSelection())
      .whereType<AddonSelection>()
      .toList();

  /// Prescription upload applies only to medical products (product_type == 5).
  bool get isMedicalProduct => productType == 5;

  /// Whether a prescription upload is mandatory before placing the order.
  bool get requiresPrescription =>
      isMedicalProduct && isPrescriptionRequired == true;

  ProductDataModel({
    this.id,
    this.name,
    this.productName,
    this.slug,
    this.images,
    this.shortDescription,
    this.productType,
    this.salesChannel,
    this.categoryId,
    this.categoryName,
    this.brandId,
    this.brandName,
    this.isUnlimitedStock,
    this.inStock,
    this.isMinAlert,
    this.isFavorite,
    this.productRating,
    this.rating,
    this.ratingCount,
    this.variantsCount,
    this.minPrice,
    this.discountPercent,
    this.variantId,
    this.sku,
    this.price,
    this.discountedPrice,
    this.stock,
    this.totalAllowedQuantity,
    this.variants,
    this.timeToDeliver,
    this.prescriptionNote,
    this.isPrescriptionRequired,
    this.currency,
    this.decimalPoint,
    this.slabDiscountMessage,
    this.estimatedDeliveryDate,
    this.hasAddons,
    this.isFood,
    this.addons,
    this.addonTotal,
    this.hasUnavailableAddons,
  });

  bool get isAvailable {
    if ((isUnlimitedStock ?? 0) == 1) return true;
    if (inStock != null) return inStock == true;
    return (stock ?? 0) > 0;
  }

  bool get isOutOfStock => !isAvailable;

  ProductDataModel.fromJson(Map<String, dynamic> json) {
    id = parseInt(json['id']);
    name = parseString(json['name']);
    productName = parseString(json['product_name']);
    slug = parseString(json['slug']);
    final rawImages = json['images'];
    if (rawImages is List) {
      images = rawImages
          .map((v) => Images.fromJson(v as Map<String, dynamic>))
          .toList();
    }
    shortDescription = parseString(json['short_description']);
    productType = parseInt(json['product_type']);
    salesChannel = parseString(json['sales_channel']);
    categoryId = parseInt(json['category_id']);
    categoryName = parseString(json['category_name']);
    brandId = parseInt(json['brand_id']);
    brandName = parseString(json['brand_name']);
    isUnlimitedStock = parseInt(json['is_unlimited_stock']);
    inStock = parseBool(json['in_stock']);
    isMinAlert = parseBool(json['is_min_alert']);
    isFavorite = parseBool(json['is_favorite']);
    productRating = parseBool(json['product_rating']);
    rating = parseDouble(json['rating']);
    ratingCount = parseInt(json['rating_count']);
    variantsCount = parseInt(json['variants_count']);
    minPrice = parseDouble(json['min_price']);
    discountPercent = parseInt(json['discount_percent']);
    variantId = parseInt(json['variant_id']);
    sku = parseString(json['sku']);
    price = parseDouble(json['price']);
    discountedPrice = parseDouble(json['discounted_price']);
    stock = parseInt(json['stock']);
    totalAllowedQuantity = parseInt(json['total_allowed_quantity']);
    final rawVariants = json['variants'];
    if (rawVariants is List) {
      variants = rawVariants
          .map((v) => Variants.fromJson(v as Map<String, dynamic>))
          .toList();
    }
    timeToDeliver = parseString(json['time_to_deliver']) ?? "";
    prescriptionNote = parseString(json['prescription_note']);
    isPrescriptionRequired =
        parseBool(json['is_prescription_required']) ?? false;
    currency = parseString(json['currency']) ?? '';
    decimalPoint = parseInt(json['decimal_point']) ?? 0;
    slabDiscountMessage = parseString(json['slab_discount_message']) ?? "";
    estimatedDeliveryDate = parseString(json['estimated_delivery_date']);
    // Add-on module.
    hasAddons = parseBool(json['has_addons']) ?? false;
    isFood = parseInt(json['is_food']) ?? 0;
    addons = parseCartAddons(json['addons']);
    addonTotal = parseDouble(json['addon_total']);
    hasUnavailableAddons = parseInt(json['has_unavailable_addons']) ?? 0;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['product_name'] = productName;
    data['slug'] = slug;
    if (images != null) {
      data['images'] = images!.map((v) => v.toJson()).toList();
    }
    data['short_description'] = shortDescription;
    data['product_type'] = productType;
    data['sales_channel'] = salesChannel;
    data['category_id'] = categoryId;
    data['category_name'] = categoryName;
    data['brand_id'] = brandId;
    data['brand_name'] = brandName;
    data['is_unlimited_stock'] = isUnlimitedStock;
    data['in_stock'] = inStock;
    data['is_min_alert'] = isMinAlert;
    data['is_favorite'] = isFavorite;
    data['product_rating'] = productRating;
    data['rating'] = rating;
    data['rating_count'] = ratingCount;
    data['variants_count'] = variantsCount;
    data['min_price'] = minPrice;
    data['discount_percent'] = discountPercent;
    data['variant_id'] = variantId;
    data['sku'] = sku;
    data['price'] = price;
    data['discounted_price'] = discountedPrice;
    data['stock'] = stock;
    data['total_allowed_quantity'] = totalAllowedQuantity;
    if (variants != null) {
      data['variants'] = variants!.map((v) => v.toJson()).toList();
    }
    data['time_to_deliver'] = timeToDeliver;
    data['prescription_note'] = prescriptionNote;
    data['is_prescription_required'] = isPrescriptionRequired == true ? 1 : 0;
    data['currency'] = currency;
    data['decimal_point'] = decimalPoint;
    data['slab_discount_message'] = slabDiscountMessage;
    data['estimated_delivery_date'] = estimatedDeliveryDate;
    // Add-on module.
    data['has_addons'] = hasAddons;
    data['is_food'] = isFood;
    data['addons'] = addons?.map((a) => a.toJson()).toList();
    data['addon_total'] = addonTotal;
    data['has_unavailable_addons'] = hasUnavailableAddons;
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

extension ProductImagesMedia on List<Images> {
  /// First image URL (video only if there is no image) — for thumbnails.
  String? get coverUrl => coverMediaUrl(map((i) => i.imageUrl));

  /// Images to page through in product cards (see [previewMedia]).
  List<Images> get preview => previewMedia(this, (i) => i.imageUrl);
}

class Variants {
  int? id;
  String? name;
  String? sku;
  String? image;
  String? attributesText;
  List<VariantAttributes>? variantAttributes;
  double? price;
  double? discountedPrice;
  int? stock;
  bool? inStock;
  int? quantity;
  int? isNotifyRequested;
  List<CustomSections>? customSections;

  Variants({
    this.id,
    this.name,
    this.sku,
    this.image,
    this.attributesText,
    this.variantAttributes,
    this.price,
    this.discountedPrice,
    this.stock,
    this.inStock,
    this.quantity,
    this.isNotifyRequested,
    this.customSections,
  });

  bool get isNotified => isNotifyRequested == 1;

  bool get isAvailable {
    if (inStock != null) return inStock == true;
    return (stock ?? 0) > 0;
  }

  bool get isOutOfStock => !isAvailable;

  Variants.fromJson(Map<String, dynamic> json) {
    id = parseInt(json['id']);
    name = parseString(json['name']);
    sku = parseString(json['sku']);
    image = parseString(json['image']);
    attributesText = parseString(json['attributes_text']);
    final rawVariantAttributes = json['variant_attributes'];
    if (rawVariantAttributes is List) {
      variantAttributes = rawVariantAttributes
          .map((v) => VariantAttributes.fromJson(v as Map<String, dynamic>))
          .toList();
    }
    price = parseDouble(json['price']);
    discountedPrice = parseDouble(json['discounted_price']);
    stock = parseInt(json['stock']);
    inStock = parseBool(json['in_stock']);
    quantity = parseInt(json['quantity']) ?? 0;
    isNotifyRequested = parseInt(json['is_notify_requested']) ?? 0;
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
    data['image'] = image;
    data['attributes_text'] = attributesText;
    if (variantAttributes != null) {
      data['variant_attributes'] = variantAttributes!
          .map((v) => v.toJson())
          .toList();
    }
    data['price'] = price;
    data['discounted_price'] = discountedPrice;
    data['stock'] = stock;
    data['in_stock'] = inStock;
    data['quantity'] = quantity;
    data['is_notify_requested'] = isNotifyRequested;
    if (customSections != null) {
      data['custom_sections'] = customSections!.map((v) => v.toJson()).toList();
    }
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
    value = parseString(json['value']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['field_label'] = fieldLabel;
    data['field_type'] = fieldType;
    data['value'] = value;
    return data;
  }
}
