/// API response envelope wrapping [AppSettingsData].
class AppSettings {
  String? status;
  String? message;
  AppSettingsData? data;

  AppSettings({this.status, this.message, this.data});

  AppSettings.fromJson(Map<String, dynamic> json) {
    status = json['status'].toString();
    message = json['message'].toString();
    data = json['data'] != null ? AppSettingsData.fromJson(json['data']) : null;
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

/// App-wide settings fetched from the backend: branding, versioning, and feature flags.
class AppSettingsData {
  String? appName;
  String? supportNumber;
  String? supportEmail;
  String? isVersionSystemOnDeliveryBoy;
  String? currentVersionDeliveryBoy;
  String? iosIsVersionSystemOnDeliveryBoy;
  String? iosCurrentVersionDeliveryBoy;
  String? requiredForceUpdateDeliveryBoy;
  String? iosRequiredForceUpdateDeliveryBoy;
  String? androidAppUrl;
  String? iosAppUrl;
  String? currency;
  String? currencyCode;
  String? decimalPoint;
  String? lowStockLimit;
  String? appModeSeller;
  String? appModeDeliveryBoy;
  String? appModeDeliveryBoyRemark;
  String? appModeDeliveryBoyStart;
  String? appModeDeliveryBoyEnd;
  String? privacyPolicyDeliveryBoy;
  String? termsConditionsDeliveryBoy;
  List<String>? allPermissions;
  String? apiKey;
  String? enableRoadPathTracking;
  String? deliveryBoyLightModeColor;
  String? deliveryBoyDarkModeColor;
  String? mapProvider;
  String? broadcastDriver;
  BroadcastConfig? broadcastConfig;
  String? deliveryBoyPlaystoreUrl;
  String? deliveryBoyAppstoreUrl;
  String? clarityProjectIdDeliveryBoy;
  String? clarityStatusDeliveryBoy;
  String? passwordMinLength;
  String? passwordMaxLength;
  String? passwordRequireUppercase;
  String? passwordRequireLowercase;
  String? passwordRequireNumber;
  String? passwordRequireSpecial;

  AppSettingsData({
    this.appName,
    this.supportNumber,
    this.supportEmail,
    this.isVersionSystemOnDeliveryBoy,
    this.currentVersionDeliveryBoy,
    this.iosIsVersionSystemOnDeliveryBoy,
    this.iosCurrentVersionDeliveryBoy,
    this.requiredForceUpdateDeliveryBoy,
    this.iosRequiredForceUpdateDeliveryBoy,
    this.androidAppUrl,
    this.iosAppUrl,
    this.currency,
    this.currencyCode,
    this.decimalPoint,
    this.lowStockLimit,
    this.appModeSeller,
    this.appModeDeliveryBoy,
    this.appModeDeliveryBoyRemark,
    this.appModeDeliveryBoyStart,
    this.appModeDeliveryBoyEnd,
    this.privacyPolicyDeliveryBoy,
    this.termsConditionsDeliveryBoy,
    this.allPermissions,
    this.apiKey,
    this.enableRoadPathTracking,
    this.deliveryBoyLightModeColor,
    this.deliveryBoyDarkModeColor,
    this.mapProvider,
    this.broadcastDriver,
    this.broadcastConfig,
    this.deliveryBoyAppstoreUrl,
    this.deliveryBoyPlaystoreUrl,
    this.clarityProjectIdDeliveryBoy,
    this.clarityStatusDeliveryBoy,
    this.passwordMinLength,
    this.passwordMaxLength,
    this.passwordRequireUppercase,
    this.passwordRequireLowercase,
    this.passwordRequireNumber,
    this.passwordRequireSpecial,
  });

  AppSettingsData.fromJson(Map<String, dynamic> json) {
    appName = json['app_name']?.toString();
    supportNumber = json['support_number']?.toString();
    supportEmail = json['support_email']?.toString();
    isVersionSystemOnDeliveryBoy =
        json['is_version_system_on_delivery_boy']?.toString();
    currentVersionDeliveryBoy = json['current_version_delivery_boy']
        ?.toString();
    iosIsVersionSystemOnDeliveryBoy =
        json['ios_is_version_system_on_delivery_boy']?.toString();
    iosCurrentVersionDeliveryBoy = json['ios_current_version_delivery_boy']
        ?.toString();
    requiredForceUpdateDeliveryBoy =
        json['required_force_update_delivery_boy']?.toString();
    iosRequiredForceUpdateDeliveryBoy =
        json['ios_required_force_update_delivery_boy']?.toString();
    androidAppUrl = json['playstore_url']?.toString();
    iosAppUrl = json['appstore_url']?.toString();
    currency = json['currency']?.toString();
    currencyCode = json['currency_code']?.toString();
    decimalPoint = json['decimal_point']?.toString();
    lowStockLimit = json['low_stock_limit']?.toString();
    appModeSeller = json['app_mode_seller']?.toString();
    appModeDeliveryBoy = json['app_mode_delivery_boy']?.toString();
    appModeDeliveryBoyRemark = json['app_mode_delivery_boy_remark']?.toString();
    appModeDeliveryBoyStart = json['app_mode_delivery_boy_start']?.toString();
    appModeDeliveryBoyEnd = json['app_mode_delivery_boy_end']?.toString();
    privacyPolicyDeliveryBoy = json['privacy_policy_delivery_boy']?.toString();
    termsConditionsDeliveryBoy = json['terms_conditions_delivery_boy']
        ?.toString();
    allPermissions = (json['allPermissions'] as List?)?.cast<String>() ?? [];
    apiKey = json['apiKey']?.toString() ?? '';
    enableRoadPathTracking =
        json['enable_road_path_tracking']?.toString() ?? '0';
    deliveryBoyLightModeColor = json['delivery_boy_light_mode_color']
        ?.toString();
    deliveryBoyDarkModeColor = json['delivery_boy_dark_mode_color']?.toString();
    mapProvider = json['map_provider']?.toString();
    broadcastDriver = json['broadcast_driver']?.toString();
    broadcastConfig = json['broadcast_config'] != null
        ? BroadcastConfig.fromJson(
            json['broadcast_config'] as Map<String, dynamic>,
          )
        : null;
    deliveryBoyPlaystoreUrl = json['delivery_boy_playstore_url'] ?? "";
    deliveryBoyAppstoreUrl = json['delivery_boy_appstore_url'] ?? "";
    clarityProjectIdDeliveryBoy =
        json['clarity_project_id_delivery_boy']?.toString() ?? "";
    clarityStatusDeliveryBoy =
        json['clarity_status_delivery_boy']?.toString() ?? "0";
    passwordMinLength = json['password_min_length']?.toString() ?? "5";
    passwordMaxLength = json['password_max_length']?.toString() ?? "0";
    passwordRequireUppercase =
        json['password_require_uppercase']?.toString() ?? "0";
    passwordRequireLowercase =
        json['password_require_lowercase']?.toString() ?? "0";
    passwordRequireNumber = json['password_require_number']?.toString() ?? "0";
    passwordRequireSpecial =
        json['password_require_special']?.toString() ?? "0";
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['app_name'] = appName;
    data['support_number'] = supportNumber;
    data['support_email'] = supportEmail;
    data['is_version_system_on_delivery_boy'] = isVersionSystemOnDeliveryBoy;
    data['current_version_delivery_boy'] = currentVersionDeliveryBoy;
    data['ios_is_version_system_on_delivery_boy'] =
        iosIsVersionSystemOnDeliveryBoy;
    data['ios_current_version_delivery_boy'] = iosCurrentVersionDeliveryBoy;
    data['required_force_update_delivery_boy'] = requiredForceUpdateDeliveryBoy;
    data['ios_required_force_update_delivery_boy'] =
        iosRequiredForceUpdateDeliveryBoy;
    data['playstore_url'] = androidAppUrl;
    data['appstore_url'] = iosAppUrl;
    data['currency'] = currency;
    data['currency_code'] = currencyCode;
    data['decimal_point'] = decimalPoint;
    data['low_stock_limit'] = lowStockLimit;
    data['app_mode_seller'] = appModeSeller;
    data['app_mode_delivery_boy'] = appModeDeliveryBoy;
    data['app_mode_delivery_boy_remark'] = appModeDeliveryBoyRemark;
    data['app_mode_delivery_boy_start'] = appModeDeliveryBoyStart;
    data['app_mode_delivery_boy_end'] = appModeDeliveryBoyEnd;
    data['privacy_policy_delivery_boy'] = privacyPolicyDeliveryBoy;
    data['terms_conditions_delivery_boy'] = termsConditionsDeliveryBoy;
    data['allPermissions'] = allPermissions;
    data['apiKey'] = apiKey;
    data['enable_road_path_tracking'] = enableRoadPathTracking;
    data['delivery_boy_light_mode_color'] = deliveryBoyLightModeColor;
    data['delivery_boy_dark_mode_color'] = deliveryBoyDarkModeColor;
    data['map_provider'] = mapProvider;
    data['broadcast_driver'] = broadcastDriver;
    data['broadcast_config'] = broadcastConfig?.toJson();
    data['delivery_boy_playstore_url'] = deliveryBoyPlaystoreUrl;
    data['delivery_boy_appstore_url'] = deliveryBoyAppstoreUrl;
    data['clarity_project_id_delivery_boy'] = clarityProjectIdDeliveryBoy;
    data['clarity_status_delivery_boy'] = clarityStatusDeliveryBoy;
    data['password_min_length'] = passwordMinLength;
    data['password_max_length'] = passwordMaxLength;
    data['password_require_uppercase'] = passwordRequireUppercase;
    data['password_require_lowercase'] = passwordRequireLowercase;
    data['password_require_number'] = passwordRequireNumber;
    data['password_require_special'] = passwordRequireSpecial;
    return data;
  }
}

/// Pusher/Reverb broadcasting connection config used for websocket chat/live-tracking.
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
