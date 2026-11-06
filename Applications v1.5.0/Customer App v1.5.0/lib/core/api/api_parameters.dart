class ApiParameters {
  ApiParameters._();

  // ── Common ────────────────────────────────────────────────────────────────
  static const String mobile = 'mobile';
  static const String password = 'password';
  static const String email = 'email';
  static const String name = 'name';
  static const String image = 'image';
  static const String status = 'status';
  static const String message = 'message';
  static const String type = 'type';
  static const String bonusType = "bonus_type";
  static const String bonusPercentage = "bonus_percentage";
  static const String phoneAuthType = "phone_auth_type";
  static const String countryCode = "country_code";
  static const String code = 'code';
  static const String phoneAuthOtp = 'phone_auth_otp';
  static const String phoneAuthPassword = 'phone_auth_password';

  // ── Auth: Login ───────────────────────────────────────────────────────────
  static const String accessToken = 'access_token';
  static const String platform = "platform";
  static const String fcmToken = 'fcm_token';
  static const String languageId = 'language_id';

  // ── Auth: Register ────────────────────────────────────────────────────────
  static const String profile = "profile";
  static const String friendsCode = "friends_code";

  // ── Auth: OTP ─────────────────────────────────────────────────────────────
  static const String otp = 'otp';

  // ── Auth: Forgot / Change Password ────────────────────────────────────────
  static const String oldPassword = 'old_password';
  static const String newPassword = 'new_password';
  static const String confirmPassword = 'confirm_password';
  static const String passwordConfirmation =
      'new_password_confirmation'; //'password_confirmation';
  static const String otpVerifyMethod = 'otp_verify_method';

  // ── Profile Update ────────────────────────────────────────────────────────
  static const String bankAccountNumber = 'bank_account_number';
  static const String bankName = 'bank_name';
  static const String accountName = 'account_name';
  static const String ifscCode = 'ifsc_code';
  static const String otherPaymentInformation = 'other_payment_information';

  // ── FCM ───────────────────────────────────────────────────────────────────
  static const String fcmId = 'fcm_id';

  // ── Orders / Misc ─────────────────────────────────────────────────────────
  static const String orderId = 'order_id';
  static const String latitude = 'latitude';
  static const String longitude = 'longitude';
  static const String isAvailable = 'is_available';
  static const String orderItemId = 'order_item_id';
  static const String cancellationReason = 'cancellation_reason';
  static const String reason = 'reason';
  static const String returnReason = 'return_reason';

  // ── Return Requests ───────────────────────────────────────────────────────
  static const String isCompleted = 'is_completed';

  // ── Pagination & Filters ──────────────────────────────────────────────────
  static const String offset = 'offset';
  static const String limit = 'limit';
  static const String search = 'search';
  static const String startDeliveryDate = 'start_delivery_date';
  static const String endDeliveryDate = 'end_delivery_date';

  // ── Date Filters ──────────────────────────────────────────────────────────
  static const String startDate = 'start_date';
  static const String endDate = 'end_date';

  // ── Spin Wheel ────────────────────────────────────────────────────────────
  static const String rewardType = 'reward_type';
  static const String requestToken = 'request_token';

  // ── Wallet ────────────────────────────────────────────────────────────────
  static const String amount = 'amount';
  static const String typeId = 'type_id';
  static const String walletAmount = 'wallet_amount';

  // ── Payment ───────────────────────────────────────────────────────────────
  static const String token = 'token';
  static const String paymentMethod = 'payment_method';
  static const String transactionId = 'transaction_id';
  static const String txnId = 'txn_id';
  static const String requestFrom = 'request_from';
  static const String deviceType = 'device_type';
  static const String appVersion = 'app_version';

  // ── Promo Code ────────────────────────────────────────────────────────────
  static const String promoCode = 'promo_code';
  static const String total = 'total';

  // ── Language Settings ────────────────────────────────────────────────────────
  static const String systemType = 'system_type';
  static const String id = 'id';
  static const String slug = 'slug';
  static const String isDefault = 'is_default';

  // ── Blog ─────────────────────────────────────────────────────────────────
  static const String categoryId = 'category_id';
  static const String tagNames = 'tag_names';

  // ── Product List: Home block data source ─────────────────────────────────
  static const String dataSource = 'data_source';
  static const String manualProductIds = 'manual_product_ids';
  static const String filterMode = 'filter_mode';
  static const String isSimilarProductId = 'is_similar_product_id';
  static const String productId = 'product_id';
  static const String parentId = 'parent_id';

  // ── Product List: Sort & Filter ──────────────────────────────────────────
  static const String sort = 'sort';
  static const String minPrice = 'min_price';
  static const String maxPrice = 'max_price';
  static const String brandIds = 'brand_ids';
  static const String attributeValues = 'attribute_value_ids';
  static const String minDiscountPercent = 'min_discount_percent';
  static const String maxDiscountPercent = 'max_discount_percent';
  static const String newType = 'new';
  static const String priceHigh = 'price_high';
  static const String priceLow = 'price_low';
  static const String discount = 'discount';
  static const String popular = 'popular';

  // ── Rating ────────────────────────────────────────────────────────────────
  static const String rate = 'rate';
  static const String review = 'review';
  static const String deleteImageIds = 'delete_image_ids';

  // ── Notification / Mail Settings ──────────────────────────────────────────
  static const String preferences = 'preferences';
  static const String key = 'key';
  static const String channels = 'channels';
  static const String mail = 'mail';
  static const String push = 'push';
  static const String sms = 'sms';

  // ── Address ───────────────────────────────────────────────────────────────
  static const String address = 'address';
  static const String alternateMobile = 'alternate_mobile';
  static const String alternateCountryCode = 'alternate_country_code';
  static const String landmark = 'landmark';
  static const String area = 'area';
  static const String pincode = 'pincode';
  static const String city = 'city';
  static const String state = 'state';
  static const String country = 'country';
  static const String countryId = 'country_id';

  // ── Orders params ───────────────────────────────────────────────────────────────
  static String active = "1";
  static String previous = "0";

  // ── Google Places ─────────────────────────────────────────────────────────────
  static const String input = 'input';
  static const String placeId = 'place_id';
  static const String latlng = 'latlng';
  static const String app = "app";
  static const String tablet = "tablet";
  static const String source = "source";

  // ── Home Layout ───────────────────────────────────────────────────────────
  static const String device = 'device';
  static const String channel = 'channel';

  // ── Cart ──────────────────────────────────────────────────────────────────
  static const String productVariantId = 'product_variant_id';
  static const String qty = 'qty';
  // Add-on module: chosen option `{id, qty}` list on cart add/remove.
  static const String addons = 'addons';
  // Add-on module: guest_cart per-item list `[{variant_id, qty, addons}]`.
  static const String items = 'items';
  static const String variantIds = 'variant_ids';
  static const String quantities = 'quantities';
  static const String isRemoveAll = 'is_remove_all';
  static const String quickVariantIds = 'quick_variant_ids';
  static const String quickQuantities = 'quick_quantities';
  static const String ecommerceVariantIds = 'ecommerce_variant_ids';
  static const String ecommerceQuantities = 'ecommerce_quantities';
  // Add-on module: bulk-add per-line basket `[{variant_id, qty, addons}]`.
  static const String quickItems = 'quick_items';
  static const String ecommerceItems = 'ecommerce_items';

  // ── Cart Recommendations ──────────────────────────────────────────────────
  static const String crossSellLimit = 'cross_sell_limit';
  static const String crossSellOffset = 'cross_sell_offset';
  static const String upsellLimit = 'upsell_limit';
  static const String upsellOffset = 'upsell_offset';

  // ── Checkout / Place Order ────────────────────────────────────────────────
  static const String deliveryType = 'delivery_type';
  static const String addressId = 'address_id';
  static const String quantity = 'quantity';
  static const String deliveryCharge = 'delivery_charge';
  static const String finalTotal = 'final_total';
  static const String walletUsed = 'wallet_used';
  static const String walletBalance = 'wallet_balance';
  static const String orderNote = 'order_note';
  static const String promoCodeId = 'promocode_id';
  static const String billingSameAsShipping = 'billing_same_as_shipping';
  static const String billingName = 'billing_name';
  static const String billingMobile = 'billing_mobile';
  static const String billingAddress = 'billing_address';
  static const String billingCity = 'billing_city';
  static const String billingPincode = 'billing_pincode';
  static const String billingCountry = 'billing_country';
  static const String billingRegionId = 'billing_region_id';
  static const String billingState = 'billing_state';
  // Buyer tax registration (GSTIN / VAT / TRN …) of whichever party is
  // billed — typed on the order form like the order note, never stored on
  // an address. `billing_tax_number` / `billing_business_name` no longer
  // exist server-side; these two are sent for shipping-billed and
  // separately-billed orders alike.
  static const String buyerTaxNumber = 'buyer_tax_number';
  static const String buyerBusinessName = 'buyer_business_name';

  /// Prescription files are keyed per product variant: `prescription[<id>]`.
  static const String prescription = 'prescription';

  // ── Chat ──────────────────────────────────────────────────────────────────
  static const String conversationId = 'conversation_id';
  static const String recipientId = 'recipient_id';
  static const String images = 'images[]';
  static const String audios = 'audios[]';
  static const String videos = 'videos[]';
  static const String files = 'files[]';
  static const String socketId = 'socket_id';
  static const String channelName = 'channel_name';

  // ── App Mode (Maintenance Window) ────────────────────────────────────────
  static const String appModeCustomerStart = 'app_mode_customer_start';
  static const String appModeCustomerEnd = 'app_mode_customer_end';
}
