import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the real Firebase plugins so a screen's `initState` can reach
/// `NotificationService` under `flutter test`.
///
/// `NotificationService.instance` builds `FirebaseMessaging.instance` in a
/// field initializer, so merely *touching* the singleton throws
/// `[core/no-app]`. Mocking the raw platform channels is not enough — modern
/// `firebase_core` talks over Pigeon channels and `Firebase.app()` reads a
/// registered-apps map — so the platform interfaces themselves are swapped
/// out here instead.
///
/// Call `await FirebaseTestHelper.setUp()` in `setUpAll` for any screen whose
/// `initState` calls into NotificationService.
class FirebaseTestHelper {
  FirebaseTestHelper._();

  static const _testOptions = FirebaseOptions(
    apiKey: 'test-api-key',
    appId: 'test-app-id',
    messagingSenderId: 'test-sender-id',
    projectId: 'test-project-id',
  );

  // flutter_local_notifications still uses a plain MethodChannel, so it gets
  // the ordinary mock-handler treatment.
  static const _localNotificationsChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );

  static Future<void> setUp() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    FirebasePlatform.instance = _FakeFirebasePlatform();
    FirebaseMessagingPlatform.instance = _FakeFirebaseMessagingPlatform();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _localNotificationsChannel,
          (call) async => null,
        );

    await Firebase.initializeApp(options: _testOptions);
  }

  static void tearDown() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_localNotificationsChannel, null);
  }
}

class _FakeFirebasePlatform extends FirebasePlatform {
  final Map<String, FirebaseAppPlatform> _apps = {};

  @override
  List<FirebaseAppPlatform> get apps => _apps.values.toList();

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    final appName = name ?? defaultFirebaseAppName;
    return _apps[appName] ??= _FakeFirebaseApp(
      appName,
      options ?? FirebaseTestHelper._testOptions,
    );
  }

  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) {
    return _apps[name] ??= _FakeFirebaseApp(
      name,
      FirebaseTestHelper._testOptions,
    );
  }
}

class _FakeFirebaseApp extends FirebaseAppPlatform {
  _FakeFirebaseApp(super.name, super.options);
}

class _FakeFirebaseMessagingPlatform extends FirebaseMessagingPlatform {
  _FakeFirebaseMessagingPlatform() : super();

  @override
  FirebaseMessagingPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseMessagingPlatform setInitialValues({bool? isAutoInitEnabled}) => this;

  @override
  Future<String?> getToken({
    String? vapidKey,
    String? serviceWorkerScriptPath,
  }) async => 'test-fcm-token';

  @override
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool announcement = false,
    bool badge = true,
    bool carPlay = false,
    bool criticalAlert = false,
    bool provisional = false,
    bool sound = true,
    bool providesAppNotificationSettings = false,
  }) async => const NotificationSettings(
    alert: AppleNotificationSetting.enabled,
    announcement: AppleNotificationSetting.disabled,
    authorizationStatus: AuthorizationStatus.authorized,
    badge: AppleNotificationSetting.enabled,
    carPlay: AppleNotificationSetting.disabled,
    lockScreen: AppleNotificationSetting.enabled,
    notificationCenter: AppleNotificationSetting.enabled,
    showPreviews: AppleShowPreviewSetting.always,
    timeSensitive: AppleNotificationSetting.disabled,
    criticalAlert: AppleNotificationSetting.disabled,
    sound: AppleNotificationSetting.enabled,
    providesAppNotificationSettings: AppleNotificationSetting.disabled,
  );

  @override
  Future<void> setAutoInitEnabled(bool? enabled) async {}

  @override
  Future<void> subscribeToTopic(String topic) async {}

  @override
  Future<void> unsubscribeFromTopic(String topic) async {}

  @override
  Future<RemoteMessage?> getInitialMessage() async => null;
}
