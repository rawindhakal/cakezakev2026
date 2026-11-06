import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:deliveryboy/features/auth/models/auth_model.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../api/etag_interceptor.dart';
import '../api/hive_box_keys.dart';

/// Encrypted Hive-backed store for the logged-in user's auth token and profile data.
class AuthHiveBox {
  AuthHiveBox._();
  static final AuthHiveBox instance = AuthHiveBox._();

  Box get _box => Hive.box(authBox);

  ValueListenable<Box> get listenable => _box.listenable();

  /// Persists the login response's token and basic user fields after a successful sign-in.
  Future<void> saveLoginData({required AuthModel auth}) async {
    final token = auth.data?.accessToken ?? '';
    final data = auth.data;

    await _box.putAll({
      kToken: token,
      kIsLoggedIn: true,
      kUserId: data?.id?.toString() ?? '',
      kUserName: data?.name ?? '',
      kUserMobile: data?.mobile ?? '',
      kUserEmail: data?.email ?? '',
      kUserProfile: data?.profileUrl ?? '',
      kUserDataJson: jsonEncode(auth.toJson()),
    });
  }

  /// Updates the cached user fields after a successful profile edit.
  Future<void> updateUserData({required AuthModel auth}) async {
    final data = auth.data;
    await _box.putAll({
      kUserName: data?.name ?? '',
      kUserMobile: data?.mobile ?? '',
      kUserEmail: data?.email ?? '',
      kUserProfile: data?.profileUrl ?? '',
      kUserDataJson: jsonEncode(auth.toJson()),
    });
  }

  String? getToken() => _box.get(kToken) as String?;

  bool get isLoggedIn => _box.get(kIsLoggedIn, defaultValue: false) as bool;

  String get userId => _box.get(kUserId, defaultValue: '') as String;

  String get userName => _box.get(kUserName, defaultValue: '') as String;

  String get userMobile => _box.get(kUserMobile, defaultValue: '') as String;

  String get userEmail => _box.get(kUserEmail, defaultValue: '') as String;

  String get userProfile => _box.get(kUserProfile, defaultValue: '') as String;

  /// Returns the last saved raw user JSON, or null if none was saved.
  Map<String, dynamic>? getUserData() {
    final raw = _box.get(kUserDataJson) as String?;
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> setFcmToken(String token) => _box.put(kFcmToken, token);

  String get fcmToken => _box.get(kFcmToken, defaultValue: '') as String;

  String? get adminConversationId => _box.get(kAdminConversationId) as String?;

  Future<void> setAdminConversationId(String id) =>
      _box.put(kAdminConversationId, id);

  String? getOrderConversationId(String orderId) =>
      _box.get('$kOrderConversationIdPrefix$orderId') as String?;

  Future<void> setOrderConversationId(String orderId, String conversationId) =>
      _box.put('$kOrderConversationIdPrefix$orderId', conversationId);

  /// Removes all stored auth data, effectively logging the user out locally.
  Future<void> clearAuth() async {
    await _box.deleteAll([
      kToken,
      kIsLoggedIn,
      kUserId,
      kUserName,
      kUserMobile,
      kUserEmail,
      kUserProfile,
      kUserDataJson,
      kAdminConversationId,
    ]);
    // Cached GET bodies may hold this user's orders / earnings / profile.
    await ETagInterceptor.clear();
  }
}
