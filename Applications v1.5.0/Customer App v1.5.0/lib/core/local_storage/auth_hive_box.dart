import 'dart:convert';
import 'package:customer/features/auth/models/auth_model.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../api/etag_interceptor.dart';
import '../api/hive_box_keys.dart';

class AuthHiveBox {
  AuthHiveBox._();
  static final AuthHiveBox instance = AuthHiveBox._();

  Box get _box => Hive.box(authBox);
  ValueListenable<Box> get listenable => _box.listenable();

  Future<void> saveLoginData({required AuthModel userLogin}) async {
    final token = userLogin.data?.accessToken ?? '';
    final data = userLogin.data;

    await _box.putAll({
      kToken: token,
      kIsLoggedIn: true,
      kUserId: data?.id ?? 0,
      kUserName: data?.name ?? '',
      kUserMobile: data?.mobile ?? '',
      kUserEmail: data?.email ?? '',
      kUserDataJson: jsonEncode(userLogin.toJson()),
    });
  }

  String? getToken() => _box.get(kToken) as String?;

  bool get isLoggedIn => _box.get(kIsLoggedIn, defaultValue: false) as bool;

  int get userId => _box.get(kUserId, defaultValue: 0) as int;

  String get userName => _box.get(kUserName, defaultValue: '') as String;

  String get userMobile => _box.get(kUserMobile, defaultValue: '') as String;

  String get userEmail => _box.get(kUserEmail, defaultValue: '') as String;

  String get referralCode => userData?.referralCode ?? '';

  String get userBalance => userData?.balance?.toString() ?? '0';

  String get userProfile => userData?.profile ?? '';

  String get userCountryCode => userData?.countryCode ?? '';

  Map<String, dynamic>? getUserData() {
    final raw = _box.get(kUserDataJson) as String?;
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  AuthModelData? get userData {
    final raw = getUserData();
    if (raw == null) return null;
    final dataMap = raw['data'];
    if (dataMap == null) return null;
    return AuthModelData.fromJson(dataMap as Map<String, dynamic>);
  }

  Future<void> updateUserSession({required AuthModel updated}) async {
    final existingToken = getToken() ?? '';
    final existingRaw = getUserData();
    final existing = existingRaw != null
        ? AuthModel.fromJson(existingRaw)
        : null;
    final existingData = existing?.data;
    final updatedData = updated.data;

    if (updatedData == null) return;

    final mergedData = AuthModelData(
      id: updatedData.id ?? existingData?.id,
      name: (updatedData.name ?? '').isNotEmpty
          ? updatedData.name
          : existingData?.name,
      email: (updatedData.email ?? '').isNotEmpty
          ? updatedData.email
          : existingData?.email,
      countryCode: (updatedData.countryCode ?? '').isNotEmpty
          ? updatedData.countryCode
          : existingData?.countryCode,
      mobile: (updatedData.mobile ?? '').isNotEmpty
          ? updatedData.mobile
          : existingData?.mobile,
      profile: (updatedData.profile ?? '').isNotEmpty
          ? updatedData.profile
          : existingData?.profile,
      balance: updatedData.balance ?? existingData?.balance,
      referralCode: (updatedData.referralCode ?? '').isNotEmpty
          ? updatedData.referralCode
          : existingData?.referralCode,
      accessToken: existingToken,
    );

    final merged = AuthModel(
      status: updated.status ?? existing?.status,
      message: updated.message ?? existing?.message,
      statusCode: updated.statusCode ?? existing?.statusCode,
      data: mergedData,
    );

    await _box.putAll({
      kIsLoggedIn: true,
      kUserId: mergedData.id ?? existingData?.id ?? 0,
      kUserName: mergedData.name ?? '',
      kUserMobile: mergedData.mobile ?? '',
      kUserEmail: mergedData.email ?? '',
      kUserDataJson: jsonEncode(merged.toJson()),
    });
  }

  Future<void> setFcmToken(String token) => _box.put(kFcmToken, token);

  String get fcmToken => _box.get(kFcmToken, defaultValue: '') as String;

  // ── Chat conversation cache ────────────────────────────────────────────
  // Avoids re-calling chat/start_admin or chat/start_order_delivery_boy on every chat
  // open — the conversation id is reused for the rest of the session.
  String? get adminConversationId => _box.get(kAdminConversationId) as String?;

  Future<void> setAdminConversationId(String id) =>
      _box.put(kAdminConversationId, id);

  String? getOrderConversationId(String orderId) =>
      _box.get('$kOrderConversationIdPrefix$orderId') as String?;

  Future<void> setOrderConversationId(String orderId, String conversationId) =>
      _box.put('$kOrderConversationIdPrefix$orderId', conversationId);

  String? getOrderAdminConversationId(String orderId) =>
      _box.get('$kOrderAdminConversationIdPrefix$orderId') as String?;

  Future<void> setOrderAdminConversationId(
    String orderId,
    String conversationId,
  ) => _box.put('$kOrderAdminConversationIdPrefix$orderId', conversationId);

  Future<void> clearAuth() async {
    await _box.deleteAll([
      kToken,
      kIsLoggedIn,
      kUserId,
      kUserName,
      kUserMobile,
      kUserEmail,
      kUserDataJson,
      kAdminConversationId,
    ]);
    // Cached GET bodies may hold this user's cart / orders / addresses.
    await ETagInterceptor.clear();
  }
}
