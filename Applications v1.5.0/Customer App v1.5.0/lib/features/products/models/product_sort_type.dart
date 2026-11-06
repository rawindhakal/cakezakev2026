import 'package:customer/core/api/api_parameters.dart';
import 'package:customer/core/localization/language_label_key.dart';

enum ProductSortType {
  defaultSort(''),
  newestFirst(ApiParameters.newType),
  priceHighToLow(ApiParameters.priceHigh),
  priceLowToHigh(ApiParameters.priceLow),
  discountHighToLow(ApiParameters.discount),
  popularity(ApiParameters.popular);

  final String apiValue;
  const ProductSortType(this.apiValue);

  String labelKey() {
    switch (this) {
      case ProductSortType.defaultSort:
        return LanguageLabelKeys.sortDefault;
      case ProductSortType.newestFirst:
        return LanguageLabelKeys.sortNewestFirst;
      case ProductSortType.priceHighToLow:
        return LanguageLabelKeys.sortPriceHighToLow;
      case ProductSortType.priceLowToHigh:
        return LanguageLabelKeys.sortPriceLowToHigh;
      case ProductSortType.discountHighToLow:
        return LanguageLabelKeys.sortDiscountHighToLow;
      case ProductSortType.popularity:
        return LanguageLabelKeys.sortPopularity;
    }
  }
}
