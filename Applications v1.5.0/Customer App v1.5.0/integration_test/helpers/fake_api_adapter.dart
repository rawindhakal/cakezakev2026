import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Canned response for one endpoint.
typedef FakeResponder = Map<String, dynamic> Function(RequestOptions options);

/// One request the adapter served, kept so a test can assert on what the app
/// actually sent (query parameters, body) rather than only which endpoint.
class RecordedRequest {
  final String path;
  final Map<String, dynamic> queryParameters;
  final dynamic data;

  RecordedRequest({
    required this.path,
    required this.queryParameters,
    required this.data,
  });
}

/// Dio adapter that answers from a path -> responder map instead of the
/// network.
///
/// Used by widget tests for screens/widgets that construct their own cubits
/// internally (so a mock cubit can't be injected): install it with
/// `ApiClient().httpClientAdapter = FakeApiAdapter({...})` and the real cubits
/// and repositories run against canned responses. The same class lives under
/// integration_test/helpers for end-to-end flows — keep the two in sync.
class FakeApiAdapter implements HttpClientAdapter {
  final Map<String, FakeResponder> responders;

  /// Every request this adapter has served, in order.
  final List<RecordedRequest> requests = [];

  /// Just the paths from [requests] — the common case.
  List<String> get requestedPaths => requests.map((r) => r.path).toList();

  /// Status code returned for a path with no responder registered. 404 makes
  /// an unstubbed endpoint fail loudly instead of silently returning success.
  static const _unstubbedStatusCode = 404;

  FakeApiAdapter(this.responders);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(
      RecordedRequest(
        path: options.path,
        queryParameters: Map<String, dynamic>.from(options.queryParameters),
        data: options.data,
      ),
    );
    final responder = responders[options.path];
    if (responder == null) {
      return ResponseBody.fromString(
        jsonEncode({'status': 0, 'message': 'No stub for ${options.path}'}),
        _unstubbedStatusCode,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode(responder(options)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
