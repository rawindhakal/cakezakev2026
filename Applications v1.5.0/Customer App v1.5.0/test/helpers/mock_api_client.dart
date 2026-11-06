import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:customer/core/api/api_client.dart';

class MockApiClient extends Mock implements ApiClient {}

class FakeFormData extends Fake implements FormData {}

class FakeOptions extends Fake implements Options {}

/// Registers mocktail fallback values needed whenever `any()` stands in for
/// a `FormData`/`Options` argument in a `when(...)`/`verify(...)` call —
/// mocktail needs a real instance to satisfy the type at registration time.
void registerApiClientFallbackValues() {
  registerFallbackValue(FakeFormData());
  registerFallbackValue(FakeOptions());
}
