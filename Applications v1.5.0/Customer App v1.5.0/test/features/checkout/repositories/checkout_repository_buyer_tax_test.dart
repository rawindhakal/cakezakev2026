import 'package:customer/core/api/api_endpoints.dart';
import 'package:customer/core/api/api_parameters.dart';
import 'package:customer/features/checkout/repositories/checkout_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_api_client.dart';

/// place_order buyer tax payload: `buyer_tax_number` / `buyer_business_name`
/// go out for whichever party is billed; the removed `billing_tax_*` params
/// never do, and an empty value is simply omitted (a normal consumer order).
void main() {
  late MockApiClient api;
  late CheckoutRepository repository;

  setUp(() {
    api = MockApiClient();
    repository = CheckoutRepository(apiClient: api);
    when(
      () => api.post(ApiEndpoints.placeOrder, data: any(named: 'data')),
    ).thenAnswer((_) async => <String, dynamic>{'status': 1});
  });

  Map<String, dynamic> sent() =>
      verify(
            () => api.post(
              ApiEndpoints.placeOrder,
              data: captureAny(named: 'data'),
            ),
          ).captured.single
          as Map<String, dynamic>;

  test('sends buyer tax fields as typed with same-as-shipping', () async {
    await repository.placeOrder(
      addressId: '1',
      paymentMethod: 'cod',
      billingSameAsShipping: true,
      buyerTaxNumber: '27 aapfu 0939 f1zv',
      buyerBusinessName: 'Acme Traders',
    );
    final data = sent();
    expect(data[ApiParameters.buyerTaxNumber], '27 aapfu 0939 f1zv');
    expect(data[ApiParameters.buyerBusinessName], 'Acme Traders');
    expect(data.containsKey('billing_tax_number'), isFalse);
    expect(data.containsKey('billing_business_name'), isFalse);
  });

  test('sends buyer tax fields with a separate billing address', () async {
    await repository.placeOrder(
      addressId: '1',
      paymentMethod: 'cod',
      billingSameAsShipping: false,
      billingName: 'Billing Party',
      buyerTaxNumber: '24ABCDE1234F1Z5',
      buyerBusinessName: 'Billing Co LLP',
    );
    final data = sent();
    expect(data[ApiParameters.buyerTaxNumber], '24ABCDE1234F1Z5');
    expect(data[ApiParameters.buyerBusinessName], 'Billing Co LLP');
  });

  test('omits empty buyer tax fields (consumer order)', () async {
    await repository.placeOrder(
      addressId: '1',
      paymentMethod: 'cod',
      buyerTaxNumber: '',
      buyerBusinessName: '',
    );
    final data = sent();
    expect(data.containsKey(ApiParameters.buyerTaxNumber), isFalse);
    expect(data.containsKey(ApiParameters.buyerBusinessName), isFalse);
  });
}
