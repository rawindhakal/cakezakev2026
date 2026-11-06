import 'package:customer/utils/json_parsers.dart';

class AppSettings {
  int? status;
  String? message;
  AppSettingsData? data;

  AppSettings({this.status, this.message, this.data});

  AppSettings.fromJson(Map<String, dynamic> json) {
    status = parseInt(json['status']);
    message = parseString(json['message']);
    data = json['data'] is Map<String, dynamic>
        ? AppSettingsData.fromJson(json['data'] as Map<String, dynamic>)
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['message'] = message;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    return data;
  }
}

class AppSettingsData {
  String? appName;
  String? supportNumber;
  String? supportEmail;
  String? maxCartItemsCount;
  String? emailLogin;
  String? phoneLogin;
  String? googleLogin;
  String? appleLogin;
  String? storeAddress;
  String? commonMetaTitle;
  String? commonMetaDescription;
  String? favicon;
  String? webLogo;
  String? placeholderImage;
  String? phoneAuthOtp;
  String? phoneAuthPassword;
  String? firebaseAuthentication;
  String? customSmsGatewayOtpBased;
  String? passwordMinLength;
  String? passwordMaxLength;
  String? passwordRequireUppercase;
  String? passwordRequireLowercase;
  String? passwordRequireNumber;
  String? passwordRequireSpecial;
  String? playstoreUrl;
  String? appstoreUrl;
  String? deliveryBoyPlaystoreUrl;
  String? deliveryBoyAppstoreUrl;
  String? isVersionSystemOnCustomer;
  String? requiredForceUpdateCustomer;
  String? currentVersionCustomer;
  String? iosIsVersionSystemOnCustomer;
  String? iosRequiredForceUpdateCustomer;
  String? iosCurrentVersionCustomer;
  String? customerLightModeColor;
  String? customerDarkModeColor;
  String? generateOtp;
  String? aboutUs;
  String? contactUs;
  String? popupEnabled;
  String? popupAlwaysShowHome;
  String? popupType;
  String? popupTypeId;
  String? popupTypeName;
  bool? popupHasChild;
  String? popupSlug;
  String? popupUrl;
  String? popupImage;
  String? deeplinkSchema;
  String? clarityProjectIdCustomer;
  String? clarityStatusCustomer;
  String? mapLatitude;
  String? mapLongitude;
  String? appModeCustomer;
  String? appModeCustomerRemark;
  String? appModeDeliveryBoy;
  String? appModeDeliveryBoyRemark;
  String? commonMetaKeywords;
  String? color;
  String? googlePlay;
  String? websiteMode;
  String? websiteModeRemark;
  String? appModeCustomerStart;
  String? appModeCustomerEnd;
  String? enableRoadPathTracking;
  String? countryCode;
  String? demoMode;
  String? broadcastDriver;
  BroadcastConfig? broadcastConfig;
  String? mapProvider;
  // 1 / 0 flag — home screen shows the spin-wheel popup only when 1.
  int? spinWheelAvailable;

  AppSettingsData({
    this.appName,
    this.supportNumber,
    this.supportEmail,
    this.maxCartItemsCount,
    this.emailLogin,
    this.phoneLogin,
    this.googleLogin,
    this.appleLogin,
    this.storeAddress,
    this.commonMetaTitle,
    this.commonMetaDescription,
    this.favicon,
    this.webLogo,
    this.placeholderImage,
    this.phoneAuthOtp,
    this.phoneAuthPassword,
    this.firebaseAuthentication,
    this.customSmsGatewayOtpBased,
    this.passwordMinLength,
    this.passwordMaxLength,
    this.passwordRequireUppercase,
    this.passwordRequireLowercase,
    this.passwordRequireNumber,
    this.passwordRequireSpecial,
    this.playstoreUrl,
    this.appstoreUrl,
    this.deliveryBoyPlaystoreUrl,
    this.deliveryBoyAppstoreUrl,
    this.isVersionSystemOnCustomer,
    this.requiredForceUpdateCustomer,
    this.currentVersionCustomer,
    this.iosIsVersionSystemOnCustomer,
    this.iosRequiredForceUpdateCustomer,
    this.iosCurrentVersionCustomer,
    this.customerLightModeColor,
    this.customerDarkModeColor,
    this.generateOtp,
    this.aboutUs,
    this.contactUs,
    this.popupEnabled,
    this.popupAlwaysShowHome,
    this.popupType,
    this.popupTypeId,
    this.popupTypeName,
    this.popupHasChild,
    this.popupSlug,
    this.popupUrl,
    this.popupImage,
    this.deeplinkSchema,
    this.clarityProjectIdCustomer,
    this.clarityStatusCustomer,
    this.mapLatitude,
    this.mapLongitude,
    this.appModeCustomer,
    this.appModeCustomerRemark,
    this.appModeDeliveryBoy,
    this.appModeDeliveryBoyRemark,
    this.commonMetaKeywords,
    this.color,
    this.googlePlay,
    this.websiteMode,
    this.websiteModeRemark,
    this.appModeCustomerStart,
    this.appModeCustomerEnd,
    this.enableRoadPathTracking,
    this.countryCode,
    this.demoMode,
    this.broadcastDriver,
    this.broadcastConfig,
    this.mapProvider,
    this.spinWheelAvailable,
  });

  AppSettingsData.fromJson(Map<String, dynamic> json) {
    appName = parseString(json['app_name']);
    supportNumber = parseString(json['support_number']);
    supportEmail = parseString(json['support_email']);
    maxCartItemsCount = parseString(json['max_cart_items_count']);
    emailLogin = parseString(json['email_login']);
    phoneLogin = parseString(json['phone_login']);
    googleLogin = parseString(json['google_login']);
    appleLogin = parseString(json['apple_login']);
    storeAddress = parseString(json['store_address']);
    commonMetaTitle = parseString(json['common_meta_title']);
    commonMetaDescription = parseString(json['common_meta_description']);
    favicon = parseString(json['favicon']);
    webLogo = parseString(json['web_logo']);
    placeholderImage = parseString(json['placeholder_image']);
    phoneAuthOtp = parseString(json['phone_auth_otp']);
    phoneAuthPassword = parseString(json['phone_auth_password']);
    firebaseAuthentication = parseString(json['firebase_authentication']);
    customSmsGatewayOtpBased = parseString(
      json['custom_sms_gateway_otp_based'],
    );
    passwordMinLength = parseString(json['password_min_length']);
    passwordMaxLength = parseString(json['password_max_length']);
    passwordRequireUppercase = parseString(json['password_require_uppercase']);
    passwordRequireLowercase = parseString(json['password_require_lowercase']);
    passwordRequireNumber = parseString(json['password_require_number']);
    passwordRequireSpecial = parseString(json['password_require_special']);
    playstoreUrl = parseString(json['playstore_url']);
    appstoreUrl = parseString(json['appstore_url']);
    deliveryBoyPlaystoreUrl = parseString(json['delivery_boy_playstore_url']);
    deliveryBoyAppstoreUrl = parseString(json['delivery_boy_appstore_url']);
    isVersionSystemOnCustomer = parseString(
      json['is_version_system_on_customer'],
    );
    requiredForceUpdateCustomer = parseString(
      json['required_force_update_customer'],
    );
    currentVersionCustomer = parseString(json['current_version_customer']);
    iosIsVersionSystemOnCustomer = parseString(
      json['ios_is_version_system_on_customer'],
    );
    iosRequiredForceUpdateCustomer = parseString(
      json['ios_required_force_update_customer'],
    );
    iosCurrentVersionCustomer = parseString(
      json['ios_current_version_customer'],
    );
    customerLightModeColor = parseString(json['customer_light_mode_color']);
    customerDarkModeColor = parseString(json['customer_dark_mode_color']);
    generateOtp = parseString(json['generate_otp']);
    aboutUs = parseString(json['about_us']);
    contactUs = parseString(json['contact_us']);
    popupEnabled = parseString(json['popup_enabled']);
    popupAlwaysShowHome = parseString(json['popup_always_show_home']);
    popupType = parseString(json['popup_type']);
    popupTypeId = parseString(json['popup_type_id']);
    popupTypeName = parseString(json['popup_type_name']);
    popupHasChild = parseBool(json['popup_has_child']);
    popupSlug = parseString(json['popup_slug']);
    popupUrl = parseString(json['popup_url']);
    popupImage = parseString(json['popup_image']);
    deeplinkSchema = parseString(json['deeplink_schema']);
    clarityProjectIdCustomer = parseString(json['clarity_project_id_customer']);
    clarityStatusCustomer = parseString(json['clarity_status_customer']);
    mapLatitude = parseString(json['map_latitude']);
    mapLongitude = parseString(json['map_longitude']);
    appModeCustomer = parseString(json['app_mode_customer']);
    appModeCustomerRemark = parseString(json['app_mode_customer_remark']);
    appModeDeliveryBoy = parseString(json['app_mode_delivery_boy']);
    appModeDeliveryBoyRemark = parseString(
      json['app_mode_delivery_boy_remark'],
    );
    commonMetaKeywords = parseString(json['common_meta_keywords']);
    color = parseString(json['color']);
    googlePlay = parseString(json['google_play']);
    websiteMode = parseString(json['website_mode']);
    websiteModeRemark = parseString(json['website_mode_remark']);
    appModeCustomerStart = parseString(json['app_mode_customer_start']);
    appModeCustomerEnd = parseString(json['app_mode_customer_end']);
    enableRoadPathTracking = parseString(json['enable_road_path_tracking']);
    countryCode = parseString(json['country_code']);
    demoMode = parseString(json['demo_mode']);
    broadcastDriver = parseString(json['broadcast_driver']);
    broadcastConfig = json['broadcast_config'] is Map<String, dynamic>
        ? BroadcastConfig.fromJson(
            json['broadcast_config'] as Map<String, dynamic>,
          )
        : null;
    mapProvider = parseString(json['map_provider']);
    spinWheelAvailable = parseInt(json['spin_wheel_available']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['app_name'] = appName;
    data['support_number'] = supportNumber;
    data['support_email'] = supportEmail;
    data['max_cart_items_count'] = maxCartItemsCount;
    data['email_login'] = emailLogin;
    data['phone_login'] = phoneLogin;
    data['google_login'] = googleLogin;
    data['apple_login'] = appleLogin;
    data['store_address'] = storeAddress;
    data['common_meta_title'] = commonMetaTitle;
    data['common_meta_description'] = commonMetaDescription;
    data['favicon'] = favicon;
    data['web_logo'] = webLogo;
    data['placeholder_image'] = placeholderImage;
    data['phone_auth_otp'] = phoneAuthOtp;
    data['phone_auth_password'] = phoneAuthPassword;
    data['firebase_authentication'] = firebaseAuthentication;
    data['custom_sms_gateway_otp_based'] = customSmsGatewayOtpBased;
    data['password_min_length'] = passwordMinLength;
    data['password_max_length'] = passwordMaxLength;
    data['password_require_uppercase'] = passwordRequireUppercase;
    data['password_require_lowercase'] = passwordRequireLowercase;
    data['password_require_number'] = passwordRequireNumber;
    data['password_require_special'] = passwordRequireSpecial;
    data['playstore_url'] = playstoreUrl;
    data['appstore_url'] = appstoreUrl;
    data['delivery_boy_playstore_url'] = deliveryBoyPlaystoreUrl;
    data['delivery_boy_appstore_url'] = deliveryBoyAppstoreUrl;
    data['is_version_system_on_customer'] = isVersionSystemOnCustomer;
    data['required_force_update_customer'] = requiredForceUpdateCustomer;
    data['current_version_customer'] = currentVersionCustomer;
    data['ios_is_version_system_on_customer'] = iosIsVersionSystemOnCustomer;
    data['ios_required_force_update_customer'] = iosRequiredForceUpdateCustomer;
    data['ios_current_version_customer'] = iosCurrentVersionCustomer;
    data['customer_light_mode_color'] = customerLightModeColor;
    data['customer_dark_mode_color'] = customerDarkModeColor;
    data['generate_otp'] = generateOtp;
    data['about_us'] = aboutUs;
    data['contact_us'] = contactUs;
    data['popup_enabled'] = popupEnabled;
    data['popup_always_show_home'] = popupAlwaysShowHome;
    data['popup_type'] = popupType;
    data['popup_type_id'] = popupTypeId;
    data['popup_type_name'] = popupTypeName;
    data['popup_has_child'] = popupHasChild;
    data['popup_slug'] = popupSlug;
    data['popup_url'] = popupUrl;
    data['popup_image'] = popupImage;
    data['deeplink_schema'] = deeplinkSchema;
    data['clarity_project_id_customer'] = clarityProjectIdCustomer;
    data['clarity_status_customer'] = clarityStatusCustomer;
    data['map_latitude'] = mapLatitude;
    data['map_longitude'] = mapLongitude;
    data['app_mode_customer'] = appModeCustomer;
    data['app_mode_customer_remark'] = appModeCustomerRemark;
    data['app_mode_delivery_boy'] = appModeDeliveryBoy;
    data['app_mode_delivery_boy_remark'] = appModeDeliveryBoyRemark;
    data['common_meta_keywords'] = commonMetaKeywords;
    data['color'] = color;
    data['google_play'] = googlePlay;
    data['website_mode'] = websiteMode;
    data['website_mode_remark'] = websiteModeRemark;
    data['app_mode_customer_start'] = appModeCustomerStart;
    data['app_mode_customer_end'] = appModeCustomerEnd;
    data['enable_road_path_tracking'] = enableRoadPathTracking;
    data['country_code'] = countryCode;
    data['demo_mode'] = demoMode;
    data['broadcast_driver'] = broadcastDriver;
    if (broadcastConfig != null) {
      data['broadcast_config'] = broadcastConfig!.toJson();
    }
    data['map_provider'] = mapProvider;
    data['spin_wheel_available'] = spinWheelAvailable;
    return data;
  }
}

class BroadcastConfig {
  final String? key;
  final String? cluster; // pusher
  final String? host; // reverb
  final String? port; // reverb
  final String? scheme; // reverb

  BroadcastConfig({this.key, this.cluster, this.host, this.port, this.scheme});

  factory BroadcastConfig.fromJson(Map<String, dynamic> json) {
    return BroadcastConfig(
      key: json['key'] as String?,
      cluster: json['cluster'] as String?,
      host: json['host'] as String?,
      port: json['port']?.toString(),
      scheme: json['scheme'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['key'] = key;
    data['cluster'] = cluster;
    data['host'] = host;
    data['port'] = port;
    data['scheme'] = scheme;
    return data;
  }
}
