import 'dart:convert';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:deliveryboy/commons/widgets/slide_to_confirm_button.dart';
import 'package:deliveryboy/core/api/api_client.dart';
import 'package:deliveryboy/core/api/api_endpoints.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/orders/cubit/order_detail_cubit.dart';
import 'package:deliveryboy/features/orders/models/order_detail_model.dart';
import 'package:deliveryboy/features/orders/widgets/delivery_otp_bottom_sheet.dart';
import 'package:deliveryboy/features/orders/widgets/order_status_slide_bar.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../helpers/fake_api_adapter.dart';
import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

class MockOrderDetailCubit extends MockCubit<OrderDetailState>
    implements OrderDetailCubit {}

/// OrderStatusSlideBar.normal builds its own OrderStatusListCubit and
/// OrderStatusUpdateCubit internally, so mock cubits can't be injected. The
/// real cubits run instead, driven through the ApiClient adapter seam.
void main() {
  late FakeApiAdapter adapter;
  late MockOrderDetailCubit orderDetailCubit;
  late OrderDetailData detail;

  Map<String, dynamic> fixture(String name) =>
      jsonDecode(File('test/fixtures/orders/$name.json').readAsStringSync())
          as Map<String, dynamic>;

  setUp(() async {
    // DioInterceptor reads the auth token out of AuthHiveBox and the language
    // code out of SettingsHiveBox on every request — with either box closed it
    // throws before the request reaches the adapter, and nothing is recorded.
    await HiveTestHelper.setUp(authBox);
    await Hive.openBox(settingsBox);

    detail = OrderDetail.fromJson(fixture('order_detail')).data!;
    orderDetailCubit = MockOrderDetailCubit();
    whenListen(
      orderDetailCubit,
      const Stream<OrderDetailState>.empty(),
      initialState: OrderDetailLoaded(detail),
    );
    when(() => orderDetailCubit.loadOrder(any())).thenAnswer((_) async {});

    adapter = FakeApiAdapter({
      ApiEndpoints.orderStatuses: (_) => fixture('order_statuses'),
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

  Future<void> pumpButton(WidgetTester tester, OrderDetailData data) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      BlocProvider<OrderDetailCubit>.value(
        value: orderDetailCubit,
        child: pumpTestWidget(
          Align(
            alignment: Alignment.bottomCenter,
            child: OrderStatusSlideBar.normal(detail: data),
          ),
        ),
      ),
    );
    // The status list is fetched in initState; give the fake adapter's
    // response time to land.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Drags the slide-to-confirm track all the way across.
  ///
  /// The thumb only fires once the accumulated drag reaches the *full* track
  /// width minus the thumb, so the sweep starts at the track's left edge and
  /// covers more than its width — a shorter drag silently snaps back instead
  /// of confirming.
  Future<void> slideToConfirm(WidgetTester tester) async {
    final track = find.byType(SlideToConfirmButton);
    final rect = tester.getRect(track);
    final gesture = await tester.startGesture(
      Offset(rect.left + 8, rect.center.dy),
    );
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('offers the next status after the current one', (tester) async {
    printTestDivider('offers the next status after the current one');
    // The order sits at active_status 5 (Out For Delivery); the status list is
    // [10, 11, 5, 6], so the next step offered is 6 (Delivered).
    await pumpButton(tester, detail);

    printTestLog('statuses fetched → expected: true, actual: ${adapter.requestedPaths.contains(ApiEndpoints.orderStatuses)}');
    expect(adapter.requestedPaths, contains(ApiEndpoints.orderStatuses));
    final button = tester.widget<SlideToConfirmButton>(
      find.byType(SlideToConfirmButton),
    );
    printTestLog('label → expected: "${LanguageLabelKeys.markAs} Delivered", actual: "${button.label}"');
    expect(button.label, '${LanguageLabelKeys.markAs} Delivered');
  });

  testWidgets('renders nothing until the status list has loaded', (
    tester,
  ) async {
    printTestDivider('renders nothing until the status list has loaded');
    await tester.pumpWidget(
      BlocProvider<OrderDetailCubit>.value(
        value: orderDetailCubit,
        child: pumpTestWidget(OrderStatusSlideBar.normal(detail: detail)),
      ),
    );
    // Only the first frame — the fetch has not resolved yet.
    await tester.pump();

    printTestLog(
      'slide button → expected: absent, actual: ${find.byType(SlideToConfirmButton).evaluate().length}',
    );
    expect(find.byType(SlideToConfirmButton), findsNothing);

    // Let the in-flight request finish so it doesn't leak into the next test.
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('offers nothing once the order is at the last status', (
    tester,
  ) async {
    printTestDivider('offers nothing once the order is at the last status');
    // 6 (Delivered) is the end of the list, so there is no next step.
    detail.order!.activeStatus = 6;
    await pumpButton(tester, detail);

    printTestLog(
      'slide button → expected: absent, actual: ${find.byType(SlideToConfirmButton).evaluate().length}',
    );
    expect(find.byType(SlideToConfirmButton), findsNothing);
  });

  testWidgets('asks for the delivery OTP before marking an order delivered', (
    tester,
  ) async {
    printTestDivider('asks for the delivery OTP before marking an order delivered');
    // The fixture order carries otp 576400, and the next status is Delivered.
    await pumpButton(tester, detail);
    await slideToConfirm(tester);

    printTestLog(
      'OTP sheet → expected: 1, actual: ${find.byType(DeliveryOtpBottomSheet).evaluate().length}',
    );
    expect(find.byType(DeliveryOtpBottomSheet), findsOneWidget);
    // Nothing is sent until the code is verified.
    printTestLog(
      'status updated → expected: false, actual: ${adapter.requestedPaths.contains(ApiEndpoints.updateStatus)}',
    );
    expect(adapter.requestedPaths, isNot(contains(ApiEndpoints.updateStatus)));
  });

  testWidgets('sends the verified OTP with the status update', (tester) async {
    printTestDivider('sends the verified OTP with the status update');
    await pumpButton(tester, detail);
    await slideToConfirm(tester);

    await tester.enterText(find.byType(TextField).first, '576400');
    await tester.pump();
    await tester.tap(find.text(LanguageLabelKeys.submit));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final update = adapter.requests.firstWhere(
      (r) => r.path == ApiEndpoints.updateStatus,
    );
    final body = update.data as Map;
    printTestLog('order status sent → expected: "6", actual: "${body['status_id']}"');
    expect(body['status_id'], '6');
    printTestLog('otp sent → expected: "576400", actual: "${body['otp']}"');
    expect(body['otp'], '576400');
  });

  testWidgets('sends nothing when the rider cancels the OTP sheet', (
    tester,
  ) async {
    printTestDivider('sends nothing when the rider cancels the OTP sheet');
    await pumpButton(tester, detail);
    await slideToConfirm(tester);

    await tester.tap(find.text(LanguageLabelKeys.cancel));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    printTestLog(
      'status updated → expected: false, actual: ${adapter.requestedPaths.contains(ApiEndpoints.updateStatus)}',
    );
    expect(adapter.requestedPaths, isNot(contains(ApiEndpoints.updateStatus)));
  });

  testWidgets('skips the OTP step for a status other than delivered', (
    tester,
  ) async {
    printTestDivider('skips the OTP step for a status other than delivered');
    // At status 10 the next step is 11 (Picked Up), which needs no OTP.
    detail.order!.activeStatus = 10;
    await pumpButton(tester, detail);
    await slideToConfirm(tester);

    printTestLog(
      'OTP sheet → expected: absent, actual: ${find.byType(DeliveryOtpBottomSheet).evaluate().length}',
    );
    expect(find.byType(DeliveryOtpBottomSheet), findsNothing);
    final update = adapter.requests.firstWhere(
      (r) => r.path == ApiEndpoints.updateStatus,
    );
    final body = update.data as Map;
    printTestLog('order status sent → expected: "11", actual: "${body['status_id']}"');
    expect(body['status_id'], '11');
  });

  testWidgets('skips the OTP step when the order carries no OTP', (
    tester,
  ) async {
    printTestDivider('skips the OTP step when the order carries no OTP');
    // An order with otp 0 is one the backend never issued a code for.
    detail.order!.otp = 0;
    await pumpButton(tester, detail);
    await slideToConfirm(tester);

    printTestLog(
      'OTP sheet → expected: absent, actual: ${find.byType(DeliveryOtpBottomSheet).evaluate().length}',
    );
    expect(find.byType(DeliveryOtpBottomSheet), findsNothing);
    printTestLog(
      'status updated → expected: true, actual: ${adapter.requestedPaths.contains(ApiEndpoints.updateStatus)}',
    );
    expect(adapter.requestedPaths, contains(ApiEndpoints.updateStatus));
  });

  testWidgets('reloads the order detail after a successful update', (
    tester,
  ) async {
    printTestDivider('reloads the order detail after a successful update');
    detail.order!.otp = 0;
    await pumpButton(tester, detail);
    await slideToConfirm(tester);

    verify(() => orderDetailCubit.loadOrder(any())).called(1);
    printTestLog('detail reloaded → verified');
  });
}
