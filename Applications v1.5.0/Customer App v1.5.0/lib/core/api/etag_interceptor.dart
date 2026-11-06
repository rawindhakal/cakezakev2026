import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../local_storage/settings_hive_box.dart';
import 'api_endpoints.dart';
import 'hive_box_keys.dart';

/// Conditional-GET support for every GET request that sends an `ETag`.
/// POST / PUT / DELETE and [_excludedPaths] are never touched.
///
/// Stores the last 200 body + its tag per request scope (URL incl. query,
/// language, channel, zone, country, auth user). Next request sends
/// `If-None-Match`; on `304 Not Modified` the stored body is replayed as a
/// normal 200 so repositories / `_handleResponse` need no changes.
///
/// Housekeeping: entries expire [_maxAge] after they were stored (pruned on
/// app start + skipped on read), the box is wiped past [_maxEntries], and
/// [clear] runs on logout via `AuthHiveBox.clearAuth`.
///
/// Must be added AFTER [DioInterceptor] so `Authorization` /
/// `Content-Language` / `channel` headers are already on the request when
/// the cache key is built.
class ETagInterceptor extends Interceptor {
  static const _cacheKeyExtra = 'etag_cache_key';
  static const _fieldEtag = 'etag';
  static const _fieldBody = 'body';
  static const _fieldSavedAt = 'saved_at';

  static const _maxAge = Duration(days: 7);
  static const _maxEntries = 300;

  // GETs that always fetch fresh — no If-None-Match, no stored body.
  static const _excludedPaths = {
    ApiEndpoints.homeLayout,
    ApiEndpoints.pageBuilder,
    ApiEndpoints.categories,
  };

  Box get _box => Hive.box(etagCacheBox);

  // Box not open (e.g. widget tests) → interceptor is a pass-through.
  bool _isTracked(RequestOptions options) =>
      Hive.isBoxOpen(etagCacheBox) &&
      options.method.toUpperCase() == 'GET' &&
      !_excludedPaths.contains(options.uri.pathSegments.lastOrNull);

  String _cacheKey(RequestOptions options) {
    final settings = SettingsHiveBox.instance;
    // User-scoped GETs (cart, orders, wallet…) must not share entries
    // across accounts — key by a hash of the bearer token, not the token.
    final auth = options.headers['Authorization'] as String?;
    return [
      options.uri.toString(),
      auth == null ? '' : auth.hashCode.toString(),
      options.headers['Content-Language'] ?? '',
      options.headers['channel'] ?? '',
      settings.zoneId ?? '',
      settings.selectedCountryId ?? '',
    ].join('|');
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!_isTracked(options)) return handler.next(options);

    final key = _cacheKey(options);
    options.extra[_cacheKeyExtra] = key;

    var cached = _box.get(key);
    if (cached is Map && _isExpired(cached)) {
      _box.delete(key);
      cached = null;
    }
    if (cached is Map && cached[_fieldEtag] is String) {
      options.headers['If-None-Match'] = cached[_fieldEtag];
      // Dio rejects 304 by default — let it through to onResponse.
      final validate = options.validateStatus;
      options.validateStatus = (status) => status == 304 || validate(status);
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final key = response.requestOptions.extra[_cacheKeyExtra] as String?;
    if (key == null) return handler.next(response);

    if (response.statusCode == 304) {
      final cached = _box.get(key);
      if (cached is Map && cached[_fieldBody] is String) {
        if (kDebugMode) {
          debugPrint('ETAG 304 => ${response.requestOptions.path} (cache hit)');
        }
        return handler.next(
          Response(
            requestOptions: response.requestOptions,
            data: jsonDecode(cached[_fieldBody] as String),
            statusCode: 200,
            headers: response.headers,
            extra: {...response.extra, 'fromETagCache': true},
          ),
        );
      }
      // Tag sent but body gone — shouldn't happen (stored together); drop
      // the stale entry so the next call fetches fresh.
      _box.delete(key);
      return handler.next(response);
    }

    final etag = response.headers.value('etag');
    final data = response.data;
    if (response.statusCode == 200 &&
        etag != null &&
        data is Map<String, dynamic> &&
        data['status'] == 1) {
      if (_box.length >= _maxEntries && !_box.containsKey(key)) _trim();
      _box.put(key, {
        _fieldEtag: etag,
        _fieldBody: jsonEncode(data),
        _fieldSavedAt: DateTime.now().millisecondsSinceEpoch,
      });
    }
    handler.next(response);
  }

  // Entries written before saved_at existed count as expired → refetched once.
  static bool _isExpired(Map entry) {
    final savedAt = entry[_fieldSavedAt];
    if (savedAt is! int) return true;
    final age = DateTime.now().millisecondsSinceEpoch - savedAt;
    return age > _maxAge.inMilliseconds;
  }

  // Over the cap: drop expired entries first; still full → wipe the box
  // (worst case the next request per URL is a plain 200).
  void _trim() {
    _pruneBox(_box);
    if (_box.length >= _maxEntries) _box.clear();
  }

  static void _pruneBox(Box box) {
    final expired = box.keys.where((k) {
      final entry = box.get(k);
      return entry is! Map || _isExpired(entry);
    }).toList();
    if (expired.isNotEmpty) box.deleteAll(expired);
  }

  /// Delete entries older than [_maxAge]. Called once on app start.
  static void pruneExpired() {
    if (!Hive.isBoxOpen(etagCacheBox)) return;
    try {
      _pruneBox(Hive.box(etagCacheBox));
    } catch (e) {
      if (kDebugMode) debugPrint('ETAG prune failed: $e');
    }
  }

  /// Wipe all stored tags/bodies (e.g. on logout).
  static Future<void> clear() async {
    if (Hive.isBoxOpen(etagCacheBox)) await Hive.box(etagCacheBox).clear();
  }
}
