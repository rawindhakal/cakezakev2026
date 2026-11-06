import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:customer/commons/utils/app_log.dart';
import 'package:customer/core/configs/app_config.dart';
import 'package:customer/core/constants/app_constants.dart';
import 'package:customer/core/constants/navigation_service.dart';
import 'package:customer/core/local_storage/settings_hive_box.dart';
import 'package:customer/core/routes/product_detail_args.dart';
import 'package:customer/core/routes/route_names.dart';
import 'package:customer/features/products/repositories/product_repository.dart';
import 'package:flutter/material.dart';

/// Handles product deep links.
///
/// Incoming link patterns handled:
///   {scheme}://product/{productId}             — custom scheme from settings API
///   {AppConfig.webUrl}/product/{productId}  — HTTPS App Links / Universal Links
///
/// Share URL produced:
///   {AppConfig.webUrl}/product/{slug}?isMobile=true
///
/// The custom scheme (e.g. "cakezake") is fetched from settings API field
/// `deep_link_scheme`. Must also be declared in AndroidManifest.xml and iOS Info.plist.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final _appLinks = AppLinks();
  final _productRepository = ProductRepository();
  StreamSubscription<Uri>? _sub;

  String get _scheme {
    final s = SettingsHiveBox.instance.getAppSettings()?.deeplinkSchema;
    return (s != null && s.isNotEmpty && s != 'null')
        ? s
        : AppConfig.deeplinkScheme;
  }

  /// Returns the share URL for a product.
  ///
  /// Always uses the HTTPS App Link on [AppConfig.webUrl] — not the raw
  /// custom scheme — so the shared link is tappable in chat apps and still
  /// opens something (website / App Link fallback) for recipients without
  /// the app installed. (Settings API's `website_mode` field isn't actually
  /// sent by the backend, so it can't be used to gate this.)
  String buildShareUrl(String slug, String productName) {
    return '${AppConfig.webUrl}/${AppConstants.deepLinkProductSegment}/$slug'
        '?${AppConstants.deepLinkIsMobileParam}=true';
  }

  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    // Cold start — app launched via link
    try {
      final initial = await _appLinks.getInitialLink();
      logDebug('DeepLinkService: getInitialLink=$initial');
      if (initial != null) {
        // Wait for splash to finish navigating so the product route lands
        // on top of the real first screen instead of racing it. Timeout is
        // a safety net only, in case splash navigation never signals ready.
        await AppNavigator.readyFuture.timeout(
          const Duration(seconds: 10),
          onTimeout: () {},
        );
        _handle(initial, navigatorKey);
      }
    } catch (_) {}

    // Warm start — link received while app running
    _sub = _appLinks.uriLinkStream.listen(
      (uri) => _handle(uri, navigatorKey),
      onError: (_) {},
    );
  }

  void _handle(Uri uri, GlobalKey<NavigatorState> navigatorKey) {
    logDebug('DeepLinkService: received uri=$uri');
    String? identifier;

    if (uri.scheme == 'https' || uri.scheme == 'http') {
      // https://web-domain/product/human-edge-in-the-ai-age (slug) or /product/123 (id)
      final segments = uri.pathSegments;
      if (segments.length >= 2 &&
          segments[0] == AppConstants.deepLinkProductSegment) {
        identifier = segments[1];
      }
    } else if (uri.scheme == _scheme) {
      if (uri.host == AppConstants.deepLinkProductSegment &&
          uri.pathSegments.isNotEmpty) {
        // cakezake://product/human-edge-in-the-ai-age
        identifier = uri.pathSegments[0];
      } else {
        // cakezake://web-domain/product/human-edge-in-the-ai-age
        // (host carries the domain instead of the "product" segment)
        final segments = uri.pathSegments;
        if (segments.length >= 2 &&
            segments[0] == AppConstants.deepLinkProductSegment) {
          identifier = segments[1];
        }
      }
    }

    logDebug('DeepLinkService: parsed identifier=$identifier');
    if (identifier != null && identifier.isNotEmpty) {
      _openProduct(identifier, navigatorKey);
    }
  }

  // The route only accepts a numeric productId, but shared links carry the
  // slug (see buildShareUrl) — resolve it via the API (which already
  // supports lookup by slug or id) before navigating.
  Future<void> _openProduct(
    String identifier,
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    int? productId = int.tryParse(identifier);
    String? imageUrl;

    if (productId == null) {
      try {
        final detail = await _productRepository.getProductDetail(
          productId: identifier,
        );
        productId = detail.data?.id;
        imageUrl = detail.data?.imageUrl;
      } catch (e) {
        logDebug(
          'DeepLinkService: failed to resolve product "$identifier": $e',
        );
        return;
      }
    }

    if (productId == null) return;

    var nav = navigatorKey.currentState;
    var attempts = 0;
    while (nav == null && attempts < 10) {
      await Future.delayed(const Duration(milliseconds: 100));
      nav = navigatorKey.currentState;
      attempts++;
    }
    logDebug(
      'DeepLinkService: resolved productId=$productId nav=${nav != null}',
    );
    if (nav == null) return;

    nav.pushNamed(
      RouteNames.productDetail,
      arguments: ProductDetailArgs(productId: productId, imageUrl: imageUrl),
    );
  }

  void dispose() {
    _sub?.cancel();
  }
}
