import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:customer/commons/utils/app_log.dart';
import 'package:customer/commons/utils/url_launcher_helper.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/local_storage/auth_hive_box.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/localization/language_label_key.dart';
import 'package:customer/core/routes/category_redirect_args.dart';
import 'package:customer/core/routes/order_detail_args.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/features/auth/repositories/auth_repository.dart';
import 'package:customer/features/chat/cubit/chat_cubit.dart';
import 'package:customer/features/chat/models/chat_message.dart';
import 'package:customer/features/notifications/notification/models/enums/notification_type.dart';
import 'package:customer/features/orders/cubit/completed_ecommerce_order_cubit.dart';
import 'package:customer/features/orders/cubit/completed_order_cubit.dart';
import 'package:customer/features/orders/cubit/ongoing_ecommerce_order_cubit.dart';
import 'package:customer/features/orders/cubit/ongoing_order_cubit.dart';
import 'package:customer/firebase_options.dart';
import 'package:customer/utils/extensions/localization_extensions.dart';
import 'package:customer/utils/json_parsers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show consolidateHttpClientResponseBytes;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';

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

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  /// Attach to MaterialApp.navigatorKey so we can navigate without context.
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final _orderPushController = StreamController<String>.broadcast();

  /// Emits the order id whenever a foreground "order" push arrives. Lets a
  /// currently-open [OrderTrackingScreen] refetch that specific order (via
  /// `OrderTrackingDetailCubit`) without relying on `context.read`, which
  /// can't reach a cubit that lives inside a pushed route from this
  /// service's root [navigatorKey] context.
  Stream<String> get orderPushStream => _orderPushController.stream;

  static const _androidChannel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
  );

  bool _localNotificationsReady = false;

  static final RegExp _urlPattern = RegExp(r'https?://\S+');

  /// First URL found in [title]/[body] (checked in that order), for pushes
  /// that embed a link directly in the copy instead of using the structured
  /// `type: "url"` + `id` fields.
  String? _extractUrl(String? title, String? body) {
    final match =
        _urlPattern.firstMatch(title ?? '') ??
        _urlPattern.firstMatch(body ?? '');
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

    // Permission prompt asked later, from home screen, not here at startup.

    // Token can rotate at any time, not just at login — keep AuthHiveBox
    // and the backend in sync whenever it does, not only on first fetch.
    final token = await _messaging.getToken();
    logDebug('FCM_TOKEN: $token');
    if (token != null) await _syncToken(token);
    _messaging.onTokenRefresh.listen(_syncToken);
  }

  /// Persists the FCM token locally, and pushes it to the backend if the
  /// user is already logged in (a fresh/guest token has nothing to attach
  /// to server-side — login flows send it themselves once authenticated).
  Future<void> _syncToken(String token) async {
    final previousToken = AuthHiveBox.instance.fcmToken;
    await AuthHiveBox.instance.setFcmToken(token);
    if (!AuthHiveBox.instance.isLoggedIn) return;
    // Same token already synced to the server for this session — skip the call.
    if (previousToken == token) return;
    try {
      await AuthRepository().updateFcmToken(
        fcmToken: token,
        platform: AppConstants.platformType,
        languageId: SettingsHiveBox.instance.languageId,
      );
    } catch (_) {
      // Best-effort — next refresh/app launch retries.
    }
  }

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

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);
  }

  void _setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((message) async {
      _refreshOrderListsIfOrderPush(message.data);
      if (await _handleChatForegroundMessage(message)) return;
      showLocalNotification(message);
    });
  }

  /// "order" pushes refetch the 4 app-wide order-listing cubits (ongoing +
  /// completed, quick + ecommerce — provided in main.dart, not owned by
  /// OrdersScreen) unconditionally, whether or not the orders screen is
  /// currently open, so the list is already fresh whenever the user next
  /// opens it. No-op if the widget tree isn't up yet (e.g. very early
  /// background isolate).
  void _refreshOrderListsIfOrderPush(Map<String, dynamic> data) {
    if (NotificationType.fromRaw(data['type'] as String?) !=
        NotificationType.order) {
      return;
    }
    final id = data['id'] as String?;
    if (id != null && id.isNotEmpty) _orderPushController.add(id);
    final context = navigatorKey.currentContext;
    if (context == null) return;
    context.read<OngoingOrderCubit>().refresh();
    context.read<CompletedOrderCubit>().refresh();
    context.read<OngoingEcommerceOrderCubit>().refresh();
    context.read<CompletedEcommerceOrderCubit>().refresh();
  }

  /// Chat pushes for the conversation the user already has open: the
  /// socket, if connected, already reflects the new message on screen, and
  /// if it's down [ChatCubit.refreshFromNotification] pulls it via REST
  /// instead — either way a popup on top of the open chat is redundant, so
  /// it's suppressed here. Returns false (and lets the normal popup show)
  /// for chat pushes on any other/no open conversation.
  Future<bool> _handleChatForegroundMessage(RemoteMessage message) async {
    if (NotificationType.fromRaw(message.data['type'] as String?) !=
        NotificationType.chat) {
      return false;
    }
    final conversationId =
        message.data['conversation_id'] as String? ??
        message.data['id'] as String?;
    final active = ChatCubit.active;
    if (active == null ||
        conversationId == null ||
        conversationId.isEmpty ||
        active.conversationId != conversationId) {
      return false;
    }
    if (!active.isSocketConnected) {
      await active.refreshFromNotification();
    }
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
      'FCM: showLocalNotification title="$title" body="$body" imageUrl="$imageUrl--${message.data.entries.map((e) => '${e.key}=${e.value}').join(', ')}"',
    );

    // Only carry title/body through to the tap payload when they actually
    // contain a link — data-only pushes already have title/body in
    // `message.data` if relevant, and leaving other pushes untouched keeps
    // existing tap behavior (including "no data → no navigation") intact.
    final payloadData = _extractUrl(title, body) != null
        ? {...message.data, 'title': title, 'body': body}
        : message.data;

    AndroidNotificationDetails androidDetails;
    DarwinNotificationDetails iosDetails;
    String? bigPicturePath;
    String? attachmentPath;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      bigPicturePath = await _downloadToLocalFile(imageUrl, 'big_picture');
      attachmentPath = bigPicturePath;
    }

    androidDetails = AndroidNotificationDetails(
      _androidChannel.id,
      _androidChannel.name,
      channelDescription: _androidChannel.description,
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
    );

    iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      attachments: attachmentPath != null
          ? [DarwinNotificationAttachment(attachmentPath)]
          : null,
    );

    await _localNotifications.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
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
      final file = File(
        '${dir.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (_) {
      return null;
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
    } catch (_) {}
  }

  /// Unified navigation handler for all click sources.
  ///
  /// Expected FCM data fields:
  ///   type          — "default" | "user" | "category" | "product" | "order" |
  ///                   "return_request" | "cart" | "url" | "wallet"
  ///   id            — resource ID (order id, product id, category id,
  ///                   conversation id for "chat", etc.) when needed, or
  ///                   the URL itself when type is "url"
  ///   order_id      — order ID; used for type "return_request"
  ///   order_item_id — ecommerce order item ID; when present for type "order",
  ///                   navigates to the ecommerce order detail screen instead
  ///   has_child     — for type "category", "true" if the category has
  ///                   sub-categories rather than products directly
  ///   type_name     — display title used for "category"/"product" screens
  ///
  /// [contentUrl] — a link found embedded in the title/body text (see
  /// [_extractUrl]), used as a fallback destination only for pushes with no
  /// structured target of their own (default/user/unknown types).
  void _navigateFromData(Map<String, dynamic> data, {String? contentUrl}) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    _refreshOrderListsIfOrderPush(data);

    final type = NotificationType.fromRaw(data['type'] as String?);
    final id = data['id'] as String?;
    final orderItemId = data['order_item_id'] as String?;
    final typeName = data['type_name'] as String?;

    if (contentUrl != null &&
        contentUrl.isNotEmpty &&
        (type == NotificationType.defaultType ||
            type == NotificationType.user ||
            type == NotificationType.unknown)) {
      openExternalUrl(contentUrl);
      return;
    }

    switch (type) {
      case NotificationType.defaultType:
      case NotificationType.user:
        navigator.pushNamed(RouteNames.notificationList);
        break;

      case NotificationType.category:
        if (id != null && id.isNotEmpty) {
          navigator.pushNamed(
            RouteNames.categories,
            arguments: CategoryRedirectArgs(
              categoryId: id,
              hasChild: parseBool(data['has_child']) ?? false,
              categoryName: typeName,
            ),
          );
        }
        break;

      case NotificationType.product:
        navigator.pushNamed(
          RouteNames.productDetail,
          arguments: int.tryParse(id ?? ''),
        );
        break;

      case NotificationType.order:
        if (orderItemId != null && orderItemId.isNotEmpty) {
          navigator.pushNamed(
            RouteNames.ecommerceOrderDetail,
            arguments: EcommerceOrderDetailArgs(orderItemId: orderItemId),
          );
        } else {
          navigator.pushNamed(RouteNames.orderDetail, arguments: id);
        }
        break;

      case NotificationType.returnRequest:
        navigator.pushNamed(
          RouteNames.orderDetail,
          arguments: data['order_id']?.toString(),
        );
        break;

      case NotificationType.cart:
        navigator.pushNamed(RouteNames.checkout);
        break;

      case NotificationType.wallet:
        navigator.pushNamed(RouteNames.walletTransactions);
        break;

      case NotificationType.chat:
        // Push payload only carries the conversation id (no
        // chatType/recipient) — chat pushes are always admin support chat,
        // same as ProfileScreen's "Chat with Support" entry point.
        navigator.pushNamed(
          RouteNames.chat,
          arguments: ChatScreenArgs(
            chatType: ChatType.adminChat,
            recipientName: navigator.context.translate(
              LanguageLabelKeys.chatWithSupport,
            ),
            recipientId: AuthHiveBox.instance.userId,
            conversationId: id,
          ),
        );
        break;

      case NotificationType.url:
        openExternalUrl(id);
        break;

      case NotificationType.unknown:
        // Unknown type — go to main screen
        navigator.pushNamedAndRemoveUntil(RouteNames.main, (route) => false);
        break;
    }
  }

  Future<String?> getToken() => _messaging.getToken();

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;
}
