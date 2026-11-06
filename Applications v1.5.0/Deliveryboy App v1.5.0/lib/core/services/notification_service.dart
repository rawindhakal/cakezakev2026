import 'dart:convert';
import 'dart:io';

import 'package:deliveryboy/core/api/api_parameters.dart';
import 'package:deliveryboy/core/local_storage/auth_hive_box.dart';
import 'package:deliveryboy/core/routes/route_names.dart';
import 'package:deliveryboy/core/utils/app_logger.dart';
import 'package:deliveryboy/features/auth/repositories/auth_repository.dart';
import 'package:deliveryboy/features/chat/cubit/chat_cubit.dart';
import 'package:deliveryboy/features/chat/models/chat_message.dart';
import 'package:deliveryboy/features/orders/cubit/order_live_tracking_cubit.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/utils/extensions/localization_extensions.dart';
import 'package:deliveryboy/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show consolidateHttpClientResponseBytes;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// When the app is fully terminated, FCM wakes a brand-new, separate Dart
/// isolate just to run this handler — none of main()'s setup (Firebase,
/// the local-notifications plugin/channel) has happened there. Skipping
/// this init is why background delivery works while the app is merely
/// backgrounded (process still warm from main()) but silently does
/// nothing once the app's been swiped away/killed.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.instance.ensureLocalNotificationsReady();
  // When `notification` is present, the OS already auto-displays it in the
  // system tray for background/terminated state — showing it again here
  // would duplicate it. Only data-only payloads need a manual show.
  if (message.notification == null) {
    await NotificationService.instance.showLocalNotification(message);
  }
}

class NotificationType {
  static const order = 'order';
  static const returnOrder = 'return_order';
  static const cashCollection = 'cash_collection';
  static const settlementHistory = 'settlement_history';
  static const salary = 'salary';
  static const url = 'url';
  static const wallet = 'wallet';
  static const chat = 'chat';
}

/// Sets up FCM push notifications and local notification display/tap-navigation.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  /// Attach to MaterialApp.navigatorKey so we can navigate without context.
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static const _androidChannel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
  );

  /// Custom-sound channel for order-assignment pushes. Android locks a
  /// channel's sound at creation time — can't reuse [_androidChannel] and
  /// just swap the sound per-notification — so assign_order pushes get
  /// their own channel with `order_sound` (res/raw/order_sound.mp3) baked in.
  static const _orderSoundChannel = AndroidNotificationChannel(
    'order_sound_channel',
    'Order Assignment Notifications',
    description: 'This channel plays a custom sound for new order assignments.',
    importance: Importance.high,
    sound: RawResourceAndroidNotificationSound('order_sound'),
  );

  bool _localNotificationsReady = false;

  static final RegExp _urlPattern = RegExp(r'https?://\S+');

  /// First URL found in [title]/[body] (checked in that order), for pushes
  /// that embed a link directly in the copy instead of using the structured
  /// `type: "url"` + `id` fields.
  String? _extractUrl(String? title, String? body) {
    final match =
        _urlPattern.firstMatch(title ?? '') ?? _urlPattern.firstMatch(body ?? '');
    return match?.group(0);
  }

  /// Safe to call from both the main isolate (via [initialize]) and the
  /// background-message isolate, which is a fresh instance of this
  /// singleton that's never run [initialize] — guarded so it only does
  /// the actual plugin setup once per isolate.
  Future<void> ensureLocalNotificationsReady() async {
    if (_localNotificationsReady) return;
    await _setupLocalNotifications();
    _localNotificationsReady = true;
  }

  /// Sets up local notifications, FCM handlers, and syncs the device token.
  Future<void> initialize() async {
    await ensureLocalNotificationsReady();
    _setupForegroundHandler();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _setupInteractedMessage();
    // alert: false — we show the alert ourselves via _localNotifications in
    // the foreground handler; leaving this true double-presents on iOS.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: false,
          badge: true,
          sound: true,
        );

    // Token can rotate at any time, not just at login — keep AuthHiveBox
    // and the backend in sync whenever it does, not only on first fetch.
    // Not awaited: on a slow/unreachable network this call can hang for a
    // long time, and initialize() itself is awaited before runApp() — a
    // stuck token fetch must not block the app from ever showing its UI.
    getToken().then((token) {
      if (token != null) _syncToken(token);
    });
    _messaging.onTokenRefresh.listen(_syncToken);
  }

  bool _tokenRegistrationInFlight = false;

  /// Claims the single add_fcm_token slot, returning false when a registration
  /// is already running. Two independent paths register the token — this
  /// service's own [_syncToken] and MainScreen's post-login retry for a blank
  /// token — and on a cold start they can both find the stored token empty
  /// before either has written it back, firing the same call twice. Callers
  /// that get `true` MUST release it with [endTokenRegistration] in a
  /// `finally`, otherwise a failed call locks out every later retry.
  bool beginTokenRegistration() {
    if (_tokenRegistrationInFlight) return false;
    _tokenRegistrationInFlight = true;
    return true;
  }

  void endTokenRegistration() => _tokenRegistrationInFlight = false;

  /// Persists the FCM token locally, and pushes it to the backend if the
  /// user is already logged in (a fresh/guest token has nothing to attach
  /// to server-side — login flow sends it itself once authenticated).
  Future<void> _syncToken(String token) async {
    final previousToken = AuthHiveBox.instance.fcmToken;
    await AuthHiveBox.instance.setFcmToken(token);
    if (!AuthHiveBox.instance.isLoggedIn) return;
    // Same token already synced to the server for this session — skip the call.
    if (previousToken == token) return;
    // Guard only the network call — the local persist above always runs, so a
    // token that rotates while the other path is mid-registration is still
    // cached and picked up on the next launch.
    if (!beginTokenRegistration()) return;
    try {
      await AuthRepository().addFcmToken(
        fcmToken: token,
        platform: Platform.isAndroid
            ? ApiParameters.android
            : ApiParameters.ios,
      );
    } catch (_) {
      // Best-effort — next refresh/app launch retries.
    } finally {
      endTokenRegistration();
    }
  }

  /// Requests notification permission from the user on both platforms.
  Future<void> requestPermission() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
  }

  Future<void> _setupLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_androidChannel);
    await androidPlugin?.createNotificationChannel(_orderSoundChannel);
  }

  void _setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((message) async {
      if (await _handleChatForegroundMessage(message)) return;
      _handleOrderForegroundMessage(message);
      showLocalNotification(message);
    });
  }

  /// Order-status pushes for the order currently open on
  /// [OrderTrackingScreen]: refreshes that screen's live tracking cubit in
  /// place (via [OrderLiveTrackingCubit.refreshFromNotification]) so it can
  /// switch store↔customer tracking / start the live-location API as soon
  /// as the status changes, without the delivery boy leaving the screen.
  /// Unlike chat, the popup notification still shows as normal — this is a
  /// side effect only.
  void _handleOrderForegroundMessage(RemoteMessage message) {
    if (message.data['type']?.toString() != NotificationType.order) return;
    final orderId = message.data['id']?.toString();
    final active = OrderLiveTrackingCubit.active;
    if (active == null || orderId == null || active.orderId != orderId) {
      return;
    }
    active.refreshFromNotification();
  }

  /// Chat pushes for the conversation the user already has open: the
  /// socket, if connected, already reflects the new message on screen, and
  /// if it's down [ChatCubit.refreshFromNotification] pulls it via REST
  /// instead — either way a popup on top of the open chat is redundant, so
  /// it's suppressed here. Returns false (and lets the normal popup show)
  /// for chat pushes on any other/no open conversation.
  Future<bool> _handleChatForegroundMessage(RemoteMessage message) async {
    if (message.data['type']?.toString() != NotificationType.chat) {
      return false;
    }
    final conversationId =
        message.data['conversation_id']?.toString() ??
        message.data['id']?.toString();
    final active = ChatCubit.active;
    if (active == null ||
        conversationId == null ||
        conversationId.isEmpty ||
        active.conversationId != conversationId) {
      return false;
    }
    // Always pull via REST, even when the socket reports "connected" —
    // that state only reflects the channel subscription, not that every
    // broadcast on it actually arrived (dropped frame, subscribe-race,
    // etc.), and refreshFromNotification merges by id so this is a no-op
    // when the socket already delivered the message.
    await active.refreshFromNotification();
    return true;
  }

  Future<void> _setupInteractedMessage() async {
    // App launched from terminated state by tapping notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _navigateFromData(
        initialMessage.data,
        contentUrl: _extractUrl(
          initialMessage.notification?.title,
          initialMessage.notification?.body,
        ),
      );
    }
    // App brought to foreground from background by tapping notification
    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _navigateFromData(
        message.data,
        contentUrl: _extractUrl(
          message.notification?.title,
          message.notification?.body,
        ),
      ),
    );
  }

  /// Displays [message] as a local notification, downloading any image attachment first.
  Future<void> showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    // Server pushes are often data-only (no `notification` block) so the
    // backend controls title/body itself — fall back to `data` fields
    // instead of dropping the message.
    final title = notification?.title ?? message.data['title'] as String?;
    final body = notification?.body ?? message.data['body'] as String?;
    if (title == null && body == null) return;

    final imageUrl =
        notification?.android?.imageUrl ??
        notification?.apple?.imageUrl ??
        message.data['image'] as String?;
    logDebug(
      () =>
          'FCM: showLocalNotification title="$title" body="$body" imageUrl="$imageUrl--${message.data.entries.map((e) => '${e.key}=${e.value}').join(', ')}"',
    );

    String? bigPicturePath;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      bigPicturePath = await _downloadToLocalFile(imageUrl, 'big_picture');
    }

    // sound_type=assign_order → play order sound via the dedicated channel
    // (Android needs the sound baked into the channel).
    final soundType = message.data['sound_type'] as String?;
    final useOrderSound = soundType == 'assign_order';
    final androidChannel = useOrderSound ? _orderSoundChannel : _androidChannel;

    // Only carry title/body through to the tap payload when they actually
    // contain a link — data-only pushes already have title/body in
    // `message.data` if relevant, and leaving other pushes untouched keeps
    // existing tap behavior (including "no data → no navigation") intact.
    final payloadData = _extractUrl(title, body) != null
        ? {...message.data, 'title': title, 'body': body}
        : message.data;

    await _localNotifications.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          androidChannel.id,
          androidChannel.name,
          channelDescription: androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/launcher_icon',
          styleInformation: bigPicturePath != null
              ? BigPictureStyleInformation(
                  FilePathAndroidBitmap(bigPicturePath),
                  contentTitle: title,
                  summaryText: body,
                  htmlFormatContentTitle: false,
                  htmlFormatSummaryText: false,
                )
              : null,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: useOrderSound ? 'order_sound.caf' : null,
          attachments: bigPicturePath != null
              ? [DarwinNotificationAttachment(bigPicturePath)]
              : null,
        ),
      ),
      // Store data as JSON so we can parse it on tap
      payload: payloadData.isEmpty ? null : jsonEncode(payloadData),
    );
  }

  /// Downloads a remote image to a temp file — Android's BigPictureStyle
  /// and iOS's DarwinNotificationAttachment both require a local file path,
  /// not a URL.
  Future<String?> _downloadToLocalFile(String url, String prefix) async {
    try {
      final response = await HttpClient()
          .getUrl(Uri.parse(url))
          .then((r) => r.close());
      if (response.statusCode != 200) return null;
      final bytes = await consolidateHttpClientResponseBytes(response);
      final dir = await getTemporaryDirectory();
      await _pruneOldTempFiles(dir, prefix);
      final file = File(
        '${dir.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Deletes previously downloaded notification images so the temp directory
  /// doesn't grow without bound — every image push used to leave a file
  /// behind forever.
  ///
  /// Only files older than a day go: a notification that's still in the tray
  /// keeps reading its bitmap from disk, so deleting the recent ones would
  /// blank out images on notifications the user can still see.
  Future<void> _pruneOldTempFiles(Directory dir, String prefix) async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(days: 1));
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        if (!entity.uri.pathSegments.last.startsWith('${prefix}_')) continue;
        if ((await entity.stat()).modified.isBefore(cutoff)) {
          await entity.delete();
        }
      }
    } catch (_) {
      // Housekeeping only — never let it block showing the notification.
    }
  }

  /// Called when user taps a local notification (foreground messages).
  void _onNotificationTap(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      _navigateFromData(
        data,
        contentUrl: _extractUrl(
          data['title'] as String?,
          data['body'] as String?,
        ),
      );
    } catch (e) {
      logDebug(() => 'NotificationService._onNotificationTap failed: $e');
    }
  }

  /// Unified navigation handler for all click sources.
  ///
  /// Expected FCM data fields:
  ///   type  — "order" | "return_order" | "cash_collection" | "settlement_history" | "salary" | "url" | "wallet"
  ///   id    — resource ID (order id, etc.) when needed, or the URL itself when type is "url"
  ///
  /// [contentUrl] — a link found embedded in the title/body text (see
  /// [_extractUrl]), used as a fallback destination only for pushes with no
  /// recognized `type` of their own.
  void _navigateFromData(Map<String, dynamic> data, {String? contentUrl}) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    // toString() rather than `as String?`: FCM data values are strings over
    // the wire, but the terminated-app path re-reads them through jsonDecode
    // of our own stored payload, where a numeric id decodes back as an int
    // and the cast would throw.
    final type = data['type']?.toString();
    final id = data['id']?.toString();

    switch (type) {
      case NotificationType.order:
        navigator.pushNamed(RouteNames.orderDetail, arguments: id);
        break;

      case NotificationType.returnOrder:
        navigator.pushNamed(RouteNames.returnOrderDetail, arguments: id);
        break;

      case NotificationType.cashCollection:
        navigator.pushNamed(RouteNames.cashCollection);
        break;

      case NotificationType.settlementHistory:
        navigator.pushNamed(RouteNames.settlementHistory);
        break;

      case NotificationType.salary:
        navigator.pushNamed(RouteNames.salary);
        break;

      case NotificationType.wallet:
        navigator.pushNamed(RouteNames.wallet);
        break;

      case NotificationType.url:
        _launchExternalUrl(id);
        break;

      case NotificationType.chat:
        // Push payload only carries the conversation id (no
        // chatType/recipient) — chat pushes are always admin support chat,
        // same as ProfileQuickHelpSection's "Chat with Support" entry point.
        navigator.pushNamed(
          RouteNames.chat,
          arguments: ChatScreenArgs(
            chatType: ChatType.adminChat,
            recipientName: navigator.context.translate(
              LanguageLabelKeys.chatWithSupport,
            ),
            recipientId: int.tryParse(AuthHiveBox.instance.userId) ?? 0,
            conversationId: id,
          ),
        );
        break;

      default:
        if (contentUrl != null && contentUrl.isNotEmpty) {
          _launchExternalUrl(contentUrl);
        } else {
          // Unknown type — go to main screen
          navigator.pushNamedAndRemoveUntil(RouteNames.main, (route) => false);
        }
        break;
    }
  }

  /// Opens a link carried by the notification payload in the browser.
  ///
  /// Only http(s) is launched — the URL arrives straight from FCM data, so
  /// other schemes (intent:, file:, market: ...) aren't opened blindly.
  void _launchExternalUrl(String? url) {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    final scheme = uri?.scheme.toLowerCase();
    if (uri == null || (scheme != 'http' && scheme != 'https')) return;
    // Fire-and-forget: nothing to show the user if the browser refuses.
    launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    ).catchError((_) => false);
  }

  /// Wraps `FirebaseMessaging.getToken()`, which throws
  /// `apns-token-not-set` on iOS when the platform hasn't handed out an APNs
  /// token yet (a real, not just simulator-only, race right after a fresh
  /// install/permission grant) — every caller already treats a null token as
  /// "nothing to sync yet", so folding that failure into null here means
  /// none of them need their own try/catch.
  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;
}
