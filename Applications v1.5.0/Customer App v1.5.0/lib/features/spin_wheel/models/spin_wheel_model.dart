import 'package:customer/features/promo_code/models/enums/promo_apply_type.dart';

// ── GET /spin_wheel — wheel config for rendering the wheel UI ───────────────

class SpinWheelResponse {
  SpinWheelResponse({this.status, this.message, this.data});

  late final int? status;
  late final String? message;
  late final SpinWheelData? data;

  SpinWheelResponse.fromJson(Map<String, dynamic> json) {
    status = json['status'] is int
        ? json['status'] as int
        : int.tryParse(json['status']?.toString() ?? '');
    message = json['message']?.toString();
    final rawData = json['data'];
    data = rawData is Map<String, dynamic>
        ? SpinWheelData.fromJson(rawData)
        : null;
  }
}

class SpinWheelData {
  SpinWheelData({
    required this.isAvailable,
    required this.requiresLogin,
    required this.message,
    required this.campaign,
    required this.segments,
    required this.spins,
    required this.currency,
    required this.currencyCode,
    required this.decimalPoint,
  });

  late final bool isAvailable;
  late final bool requiresLogin;
  late final String message;
  late final SpinCampaign? campaign;
  late final List<SpinSegment> segments;
  late final SpinInfo? spins;
  late final String currency;
  late final String currencyCode;
  late final int decimalPoint;

  SpinWheelData.fromJson(Map<String, dynamic> json) {
    isAvailable = json['is_available'] == 1 || json['is_available'] == true;
    requiresLogin =
        json['requires_login'] == 1 || json['requires_login'] == true;
    message = json['message']?.toString() ?? '';
    final rawCampaign = json['campaign'];
    campaign = rawCampaign is Map<String, dynamic>
        ? SpinCampaign.fromJson(rawCampaign)
        : null;
    final rawSegments = json['segments'];
    segments = rawSegments is List
        ? rawSegments
              .map((e) => SpinSegment.fromJson(e as Map<String, dynamic>))
              .toList()
        : [];
    final rawSpins = json['spins'];
    spins = rawSpins is Map<String, dynamic>
        ? SpinInfo.fromJson(rawSpins)
        : null;
    currency = json['currency']?.toString() ?? '';
    currencyCode = json['currency_code']?.toString() ?? '';
    decimalPoint = int.tryParse(json['decimal_point']?.toString() ?? '') ?? 2;
  }
}

class SpinCampaign {
  SpinCampaign({required this.id, required this.name, required this.theme});

  late final String id;
  late final String name;
  late final SpinTheme? theme;

  SpinCampaign.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString() ?? '';
    name = json['name']?.toString() ?? '';
    final rawTheme = json['theme'];
    theme = rawTheme is Map<String, dynamic>
        ? SpinTheme.fromJson(rawTheme)
        : null;
  }
}

class SpinTheme {
  SpinTheme({
    required this.bgColor,
    required this.lightColor,
    required this.titleColor,
    required this.titleColor2,
    required this.pointerColor,
    required this.borderColor,
    required this.lineColor,
    required this.buttonColor,
    required this.buttonText,
    required this.segmentFill,
    required this.hubIconUrl,
  });

  late final String bgColor;
  late final String lightColor;
  late final String titleColor;
  late final String titleColor2;
  late final String pointerColor;
  late final String borderColor;
  late final String lineColor;
  late final String buttonColor;
  late final String buttonText;
  late final String segmentFill;
  late final String hubIconUrl;

  SpinTheme.fromJson(Map<String, dynamic> json) {
    bgColor = json['bg_color']?.toString() ?? '';
    lightColor = json['light_color']?.toString() ?? '';
    titleColor = json['title_color']?.toString() ?? '';
    titleColor2 = json['title_color_2']?.toString() ?? '';
    pointerColor = json['pointer_color']?.toString() ?? '';
    borderColor = json['border_color']?.toString() ?? '';
    lineColor = json['line_color']?.toString() ?? '';
    buttonColor = json['button_color']?.toString() ?? '';
    buttonText = json['button_text']?.toString() ?? '';
    segmentFill = json['segment_fill']?.toString() ?? '';
    hubIconUrl = json['hub_icon_url']?.toString() ?? '';
  }
}

class SpinSegment {
  SpinSegment({
    required this.index,
    required this.id,
    required this.label,
    required this.displayMode,
    required this.color,
    required this.textColor,
    required this.iconUrl,
  });

  late final int index;
  late final String id;
  late final String label;
  late final String displayMode;
  late final String color;
  late final String textColor;
  late final String iconUrl;

  SpinSegment.fromJson(Map<String, dynamic> json) {
    index = int.tryParse(json['index']?.toString() ?? '') ?? 0;
    id = json['id']?.toString() ?? '';
    label = json['label']?.toString() ?? '';
    displayMode = json['display_mode']?.toString() ?? '';
    color = json['color']?.toString() ?? '';
    textColor = json['text_color']?.toString() ?? '';
    iconUrl = json['icon_url']?.toString() ?? '';
  }
}

class SpinInfo {
  SpinInfo({
    required this.spinsPerDay,
    required this.usedToday,
    required this.remainingToday,
    required this.maxSpinsPerUser,
    required this.usedLifetime,
    required this.remainingLifetime,
    required this.canSpin,
    required this.reason,
    required this.nextSpinAt,
    required this.nextSpinAtLabel,
    required this.nextSpinInSeconds,
  });

  late final int spinsPerDay;
  late final int usedToday;
  late final int remainingToday;
  late final int maxSpinsPerUser;
  late final int usedLifetime;
  late final int? remainingLifetime;
  late final bool canSpin;
  late final String reason;
  late final String? nextSpinAt;
  late final String nextSpinAtLabel;
  late final int? nextSpinInSeconds;

  SpinInfo.fromJson(Map<String, dynamic> json) {
    spinsPerDay = int.tryParse(json['spins_per_day']?.toString() ?? '') ?? 0;
    usedToday = int.tryParse(json['used_today']?.toString() ?? '') ?? 0;
    remainingToday =
        int.tryParse(json['remaining_today']?.toString() ?? '') ?? 0;
    maxSpinsPerUser =
        int.tryParse(json['max_spins_per_user']?.toString() ?? '') ?? 0;
    usedLifetime = int.tryParse(json['used_lifetime']?.toString() ?? '') ?? 0;
    remainingLifetime = json['remaining_lifetime'] == null
        ? null
        : int.tryParse(json['remaining_lifetime'].toString());
    canSpin = json['can_spin'] == true;
    reason = json['reason']?.toString() ?? '';
    nextSpinAt = json['next_spin_at']?.toString();
    nextSpinAtLabel = json['next_spin_at_label']?.toString() ?? '';
    nextSpinInSeconds = json['next_spin_in_seconds'] == null
        ? null
        : double.tryParse(json['next_spin_in_seconds'].toString())?.round();
  }
}

// ── POST /spin_wheel/spin — result of one spin ───────────────────────────────

class SpinResultResponse {
  SpinResultResponse({this.status, this.message, this.data});

  late final int? status;
  late final String? message;
  late final SpinResultData? data;

  SpinResultResponse.fromJson(Map<String, dynamic> json) {
    status = json['status'] is int
        ? json['status'] as int
        : int.tryParse(json['status']?.toString() ?? '');
    message = json['message']?.toString();
    final rawData = json['data'];
    data = rawData is Map<String, dynamic>
        ? SpinResultData.fromJson(rawData)
        : null;
  }
}

class SpinResultData {
  SpinResultData({
    required this.segmentId,
    required this.segmentIndex,
    required this.result,
    required this.rewardType,
    required this.label,
    required this.title,
    required this.message,
    required this.promoCode,
    required this.wallet,
    required this.spins,
    required this.currency,
    required this.currencyCode,
    required this.decimalPoint,
    required this.reward,
  });

  late final String segmentId;
  late final int segmentIndex;
  late final String result;
  late final String rewardType;
  late final String label;
  late final String title;
  late final String message;
  late final SpinPromoCode? promoCode;
  late final dynamic wallet;
  late final SpinInfo? spins;
  late final String currency;
  late final String currencyCode;
  late final int decimalPoint;
  // Same shape as a `SpinReward` from the /rewards history list — lets a
  // freshly-won reward be prepended straight into that list's state
  // without a refetch. Null on a "no_luck" result.
  late final SpinReward? reward;

  bool get isWin => result == 'win';
  bool get isNoLuck => rewardType == 'no_luck';

  SpinResultData.fromJson(Map<String, dynamic> json) {
    segmentId = json['segment_id']?.toString() ?? '';
    segmentIndex = int.tryParse(json['segment_index']?.toString() ?? '') ?? 0;
    result = json['result']?.toString() ?? '';
    rewardType = json['reward_type']?.toString() ?? '';
    label = json['label']?.toString() ?? '';
    title = json['title']?.toString() ?? '';
    message = json['message']?.toString() ?? '';
    final rawPromoCode = json['promo_code'];
    promoCode = rawPromoCode is Map<String, dynamic>
        ? SpinPromoCode.fromJson(rawPromoCode)
        : null;
    wallet = json['wallet'];
    final rawSpins = json['spins'];
    spins = rawSpins is Map<String, dynamic>
        ? SpinInfo.fromJson(rawSpins)
        : null;
    currency = json['currency']?.toString() ?? '';
    currencyCode = json['currency_code']?.toString() ?? '';
    decimalPoint = int.tryParse(json['decimal_point']?.toString() ?? '') ?? 2;
    final rawReward = json['reward'];
    reward = rawReward is Map<String, dynamic>
        ? SpinReward.fromJson(rawReward)
        : null;
  }
}

class SpinPromoCode {
  SpinPromoCode({
    required this.id,
    required this.promoCode,
    required this.title,
    required this.discountType,
    required this.discount,
    required this.maxDiscountAmount,
    required this.minimumOrderAmount,
    required this.startDate,
    required this.endDate,
    required this.startDateLabel,
    required this.endDateLabel,
  });

  late final String id;
  late final String promoCode;
  late final String title;
  late final String discountType;
  late final num discount;
  late final num maxDiscountAmount;
  late final num minimumOrderAmount;
  late final String startDate;
  late final String endDate;
  late final String startDateLabel;
  late final String endDateLabel;

  SpinPromoCode.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString() ?? '';
    promoCode = json['promo_code']?.toString() ?? '';
    title = json['title']?.toString() ?? '';
    discountType = json['discount_type']?.toString() ?? '';
    discount = num.tryParse(json['discount']?.toString() ?? '') ?? 0;
    maxDiscountAmount =
        num.tryParse(json['max_discount_amount']?.toString() ?? '') ?? 0;
    minimumOrderAmount =
        num.tryParse(json['minimum_order_amount']?.toString() ?? '') ?? 0;
    startDate = json['start_date']?.toString() ?? '';
    endDate = json['end_date']?.toString() ?? '';
    startDateLabel = json['start_date_label']?.toString() ?? '';
    endDateLabel = json['end_date_label']?.toString() ?? '';
  }
}

// ── GET /spin_wheel/rewards — paginated reward history ───────────────────────

class SpinRewardsResponse {
  SpinRewardsResponse({this.status, this.message, this.total, this.data});

  late final int? status;
  late final String? message;
  late final int? total;
  late final SpinRewardsData? data;

  SpinRewardsResponse.fromJson(Map<String, dynamic> json) {
    status = json['status'] is int
        ? json['status'] as int
        : int.tryParse(json['status']?.toString() ?? '');
    message = json['message']?.toString();
    total = int.tryParse(json['total']?.toString() ?? '');
    final rawData = json['data'];
    data = rawData is Map<String, dynamic>
        ? SpinRewardsData.fromJson(rawData)
        : null;
  }
}

class SpinRewardsData {
  SpinRewardsData({required this.rewards, required this.summary});

  late final List<SpinReward> rewards;
  late final SpinRewardsSummary? summary;

  SpinRewardsData.fromJson(Map<String, dynamic> json) {
    final rawRewards = json['rewards'];
    rewards = rawRewards is List
        ? rawRewards
              .map((e) => SpinReward.fromJson(e as Map<String, dynamic>))
              .toList()
        : [];
    final rawSummary = json['summary'];
    summary = rawSummary is Map<String, dynamic>
        ? SpinRewardsSummary.fromJson(rawSummary)
        : null;
  }
}

class SpinReward {
  SpinReward({
    required this.id,
    required this.rewardType,
    required this.label,
    required this.campaignName,
    required this.iconUrl,
    required this.amount,
    required this.currency,
    required this.currencyCode,
    required this.wonAt,
    required this.wonAtLabel,
    required this.promoCode,
  });

  late final String id;
  late final String rewardType;
  late final String label;
  late final String campaignName;
  late final String iconUrl;
  late final num amount;
  late final String currency;
  late final String currencyCode;
  late final String wonAt;
  late final String wonAtLabel;
  late final SpinRewardPromoCode? promoCode;

  SpinReward.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString() ?? '';
    rewardType = json['reward_type']?.toString() ?? '';
    label = json['label']?.toString() ?? '';
    campaignName = json['campaign_name']?.toString() ?? '';
    iconUrl = json['icon_url']?.toString() ?? '';
    amount = num.tryParse(json['amount']?.toString() ?? '') ?? 0;
    currency = json['currency']?.toString() ?? '';
    currencyCode = json['currency_code']?.toString() ?? '';
    wonAt = json['won_at']?.toString() ?? '';
    wonAtLabel = json['won_at_label']?.toString() ?? '';
    final rawPromoCode = json['promo_code'];
    promoCode = rawPromoCode is Map<String, dynamic>
        ? SpinRewardPromoCode.fromJson(rawPromoCode)
        : null;
  }
}

class SpinRewardPromoCode {
  SpinRewardPromoCode({
    required this.promoCode,
    required this.discountType,
    required this.discountApplyType,
    required this.discount,
    required this.maxDiscountAmount,
    required this.minimumOrderAmount,
    required this.startDate,
    required this.endDate,
    required this.endDateLabel,
  });

  late final String promoCode;
  late final String discountType;
  late final String discountApplyType;
  late final num discount;
  late final num maxDiscountAmount;
  late final num minimumOrderAmount;
  late final String startDate;
  late final String endDate;
  late final String endDateLabel;

  PromoApplyType get discountApplyTypeEnum =>
      PromoApplyType.fromRaw(discountApplyType);

  // Compared as calendar dates (time-stripped) so a promo stays valid for
  // the whole of its end_date, not just until midnight.
  bool get isExpired {
    final parsedEnd = DateTime.tryParse(endDate);
    if (parsedEnd == null) return false;
    final today = DateTime.now();
    final endDay = DateTime(parsedEnd.year, parsedEnd.month, parsedEnd.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    return endDay.isBefore(todayDay);
  }

  SpinRewardPromoCode.fromJson(Map<String, dynamic> json) {
    promoCode = json['promo_code']?.toString() ?? '';
    discountType = json['discount_type']?.toString() ?? '';
    discountApplyType = json['discount_apply_type']?.toString() ?? '';
    discount = num.tryParse(json['discount']?.toString() ?? '') ?? 0;
    maxDiscountAmount =
        num.tryParse(json['max_discount_amount']?.toString() ?? '') ?? 0;
    minimumOrderAmount =
        num.tryParse(json['minimum_order_amount']?.toString() ?? '') ?? 0;
    startDate = json['start_date']?.toString() ?? '';
    endDate = json['end_date']?.toString() ?? '';
    endDateLabel = json['end_date_label']?.toString() ?? '';
  }
}

class SpinRewardsSummary {
  SpinRewardsSummary({
    required this.spins,
    required this.wins,
    required this.walletWon,
  });

  late final int spins;
  late final int wins;
  late final num walletWon;

  SpinRewardsSummary.fromJson(Map<String, dynamic> json) {
    spins = int.tryParse(json['spins']?.toString() ?? '') ?? 0;
    wins = int.tryParse(json['wins']?.toString() ?? '') ?? 0;
    walletWon = num.tryParse(json['wallet_won']?.toString() ?? '') ?? 0;
  }
}
