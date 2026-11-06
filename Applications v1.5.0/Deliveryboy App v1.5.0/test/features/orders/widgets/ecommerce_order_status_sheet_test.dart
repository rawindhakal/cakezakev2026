import 'dart:convert';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/commons/cubit/base_async_cubit.dart';
import 'package:deliveryboy/commons/widgets/slide_to_confirm_button.dart';
import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/orders/cubit/ecommerce_order_detail_cubit.dart';
import 'package:deliveryboy/features/orders/models/ecommerce_order_model.dart';
import 'package:deliveryboy/features/orders/widgets/order_status_slide_bar.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../helpers/fake_api_adapter.dart';
import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

class MockEcommerceOrderDetailCubit
    extends MockCubit<AsyncState<EcommerceOrderDataModel>>
    implements EcommerceOrderDetailCubit {}

/// OrderStatusSlideBar.ecommerce builds its own OrderStatusListCubit and
/// OrderStatusUpdateCubit internally (channel: ecommerce), so — like the
/// quick-order flow — the real cubits run through the ApiClient adapter seam
/// rather than being mocked in.
void main() {
  late FakeApiAdapter adapter;
  late MockEcommerceOrderDetailCubit detailCubit;
  late EcommerceOrderDataModel order;

  Map<String, dynamic> fixture(String name) =>
      jsonDecode(File('test/fixtures/orders/$name.json').readAsStringSync())
          as Map<String, dynamic>;

  setUp(() async {
    await HiveTestHelper.setUp(authBox);
    await Hive.openBox(settingsBox);

    final list = fixture('ecommerce_orders_list')['data'] as List;
    order = EcommerceOrderDataModel.fromJson(
      Map<String, dynamic>.from(list.first as Map),
    );

    detailCubit = MockEcommerceOrderDetailCubit();
    whenListen(
      detailCubit,
      const Stream<AsyncState<EcommerceOrderDataModel>>.empty(),
      initialState: AsyncLoaded(order),
    );
    when(() => detailCubit.loadOrderDetail(any())).thenAnswer((_) async {});

    adapter = FakeApiAdapter({
      ApiEndpoints.orderStatuses: (_) => fixture('ecommerce_order_statuses'),
      ApiEndpoints.updateStatus: (_) => {
        'status': 1,
        'message': 'Order status updated',
      },
    });
    ApiClient().httpClientAdapter = adapter;
  });

  tearDown(() async {
    await Hive.box(settingsBox).close();
    await Hive.deleteBoxFromDisk(settingsBox);
    await HiveTestHelper.tearDown(authBox);
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpButton(WidgetTester tester, EcommerceOrderDataModel data) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      BlocProvider<EcommerceOrderDetailCubit>.value(
        value: detailCubit,
        child: pumpTestWidget(
          Align(
            alignment: Alignment.bottomCenter,
            child: OrderStatusSlideBar.ecommerce(order: data),
          ),
        ),
      ),
    );
    // The status list is fetched in initState; give the fake adapter's
    // response time to land.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('offers the next status after the current one', (tester) async {
    printTestDivider('offers the next status after the current one');
    // Fixture ships active_status 6 (Delivered) — force 5 (Out For Delivery)
    // so a next step (6) exists to offer.
    order.activeStatus = 5;
    await pumpButton(tester, order);

    printTestLog(
      'statuses fetched → expected: true, actual: ${adapter.requestedPaths.contains(ApiEndpoints.orderStatuses)}',
    );
    expect(adapter.requestedPaths, contains(ApiEndpoints.orderStatuses));
    final button = tester.widget<SlideToConfirmButton>(
      find.byType(SlideToConfirmButton),
    );
    printTestLog('label → expected: "${LanguageLabelKeys.markAs} Delivered", actual: "${button.label}"');
    expect(button.label, '${LanguageLabelKeys.markAs} Delivered');
  });

  testWidgets('renders nothing until the status list has loaded', (tester) async {
    printTestDivider('renders nothing until the status list has loaded');
    order.activeStatus = 5;
    await tester.pumpWidget(
      BlocProvider<EcommerceOrderDetailCubit>.value(
        value: detailCubit,
        child: pumpTestWidget(OrderStatusSlideBar.ecommerce(order: order)),
      ),
    );
    // Only the first frame — the fetch has not resolved yet.
    await tester.pump();

    printTestLog(
      'slide button → expected: absent, actual: ${find.byType(SlideToConfirmButton).evaluate().length}',
    );
    expect(find.byType(SlideToConfirmButton), findsNothing);

    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('offers nothing once the order is at the last status', (tester) async {
    printTestDivider('offers nothing once the order is at the last status');
    // 6 (Delivered) is the end of the ecommerce status list, so no next step.
    order.activeStatus = 6;
    await pumpButton(tester, order);

    printTestLog(
      'slide button → expected: absent, actual: ${find.byType(SlideToConfirmButton).evaluate().length}',
    );
    expect(find.byType(SlideToConfirmButton), findsNothing);
  });

  testWidgets(
    'confirming the slide sends the next status and reloads the order',
    (tester) async {
      printTestDivider('confirming the slide sends the next status and reloads the order');
      // Give the order a next status that is not "Delivered" so the button
      // fires immediately without needing an OTP sheet in between.
      order.activeStatus = 5;
      order.otp = null;
      await pumpButton(tester, order);

      final track = find.byType(SlideToConfirmButton);
      final rect = tester.getRect(track);
      final gesture = await tester.startGesture(Offset(rect.left + 8, rect.center.dy));
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(const Offset(40, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      printTestLog(
        'status update requested → expected: true, actual: ${adapter.requestedPaths.contains(ApiEndpoints.updateStatus)}',
      );
      expect(adapter.requestedPaths, contains(ApiEndpoints.updateStatus));
      verify(() => detailCubit.loadOrderDetail(order.id.toString())).called(1);
    },
  );
}
