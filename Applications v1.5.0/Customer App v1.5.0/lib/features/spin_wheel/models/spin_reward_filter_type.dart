import 'package:customer/core/localization/language_label_key.dart';

/// Filter for [SpinWheelRewardsCubit]'s `reward_type` query param — matches
/// `SpinReward.rewardType`'s own values ("wallet" / "promo_code" /
/// "free_delivery") coming back from the rewards API. [all] sends an empty
/// string, per the API contract, to mean "no filter".
enum SpinRewardFilterType {
  all(''),
  wallet('wallet'),
  promoCode('promo_code'),
  freeDelivery('free_delivery');

  final String apiValue;
  const SpinRewardFilterType(this.apiValue);

  String labelKey() {
    switch (this) {
      case SpinRewardFilterType.all:
        return LanguageLabelKeys.filterAll;
      case SpinRewardFilterType.wallet:
        return LanguageLabelKeys.wallet;
      case SpinRewardFilterType.promoCode:
        return LanguageLabelKeys.promoCode;
      case SpinRewardFilterType.freeDelivery:
        return LanguageLabelKeys.freeDelivery;
    }
  }
}
