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
import 'package:deliveryboy/features/orders/cubit/return_order_detail_cubit.dart';
import 'package:deliveryboy/features/orders/models/return_order_model.dart';
import 'package:deliveryboy/features/orders/widgets/order_status_slide_bar.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../helpers/fake_api_adapter.dart';
import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

class MockReturnOrderDetailCubit extends MockCubit<ReturnOrderDetailState>
    implements ReturnOrderDetailCubit {}

/// OrderStatusSlideBar.returnOrder builds its own status-list and update
/// cubits, so they can't be injected — the real ones run against the
/// ApiClient adapter seam instead.
void main() {
  late FakeApiAdapter adapter;
  late MockReturnOrderDetailCubit detailCubit;
  late ReturnRequestData detail;

  Map<String, dynamic> fixture(String name) =>
      jsonDecode(File('test/fixtures/orders/$name.json').readAsStringSync())
          as Map<String, dynamic>;

  setUp(() async {
    // DioInterceptor reads the auth token and the language code on every
    // request; with either box closed it throws before reaching the adapter.
    await HiveTestHelper.setUp(authBox);
    await Hive.openBox(settingsBox);

    detail = ReturnDetailResponse.fromJson(fixture('return_order_detail')).data!;
    detailCubit = MockReturnOrderDetailCubit();
    whenListen(
      detailCubit,
      const Stream<ReturnOrderDetailState>.empty(),
      initialState: ReturnOrderDetailLoaded(detail),
    );
    when(() => detailCubit.loadDetail(any())).thenAnswer((_) async {});

    adapter = FakeApiAdapter({
      ApiEndpoints.orderStatuses: (_) => fixture('return_order_statuses'),
      ApiEndpoints.returnRequestStatusUpdate: (_) => {
        'status': 1,
        'message': 'Return status updated',
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

  Future<void> pumpButton(WidgetTester tester, ReturnRequestData data) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      BlocProvider<ReturnOrderDetailCubit>.value(
        value: detailCubit,
        child: pumpTestWidget(
          Align(
            alignment: Alignment.bottomCenter,
            child: OrderStatusSlideBar.returnOrder(detail: data),
          ),
        ),
      ),
    );
    // The status list is fetched on build; give the fake adapter time to land.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Drags the slide-to-confirm track across its full width — a shorter sweep
  /// silently snaps back instead of confirming.
  Future<void> slideToConfirm(WidgetTester tester) async {
    final rect = tester.getRect(find.byType(SlideToConfirmButton));
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

  testWidgets('offers the next return status after the current one', (
    tester,
  ) async {
    printTestDivider('offers the next return status after the current one');
    // Return statuses run [5 Out for Pickup, 6 Received from Customer,
    // 7 Return to Store]; a request at 5 is offered 6 next.
    detail.status = 5;
    await pumpButton(tester, detail);

    printTestLog('statuses fetched → expected: true, actual: ${adapter.requestedPaths.contains(ApiEndpoints.orderStatuses)}');
    expect(adapter.requestedPaths, contains(ApiEndpoints.orderStatuses));
    final button = tester.widget<SlideToConfirmButton>(
      find.byType(SlideToConfirmButton),
    );
    printTestLog('label → expected: to contain "Received from Customer", actual: "${button.label}"');
    expect(button.label, contains('Received from Customer'));
  });

  testWidgets('offers nothing once the request has reached the store', (
    tester,
  ) async {
    printTestDivider('offers nothing once the request has reached the store');
    // 7 is the last step in the list, so there is no next one.
    detail.status = 7;
    await pumpButton(tester, detail);

    printTestLog('slide button → expected: absent, actual: ${find.byType(SlideToConfirmButton).evaluate().length}');
    expect(find.byType(SlideToConfirmButton), findsNothing);
  });

  testWidgets('offers nothing for a rejected request', (tester) async {
    printTestDivider('offers nothing for a rejected request');
    // A rejected return is terminal for the rider regardless of list order.
    detail.status = 3;
    await pumpButton(tester, detail);

    printTestLog('slide button → expected: absent, actual: ${find.byType(SlideToConfirmButton).evaluate().length}');
    expect(find.byType(SlideToConfirmButton), findsNothing);
  });

  testWidgets('renders nothing until the status list has loaded', (
    tester,
  ) async {
    printTestDivider('renders nothing until the status list has loaded');
    detail.status = 5;
    await tester.pumpWidget(
      BlocProvider<ReturnOrderDetailCubit>.value(
        value: detailCubit,
        child: pumpTestWidget(OrderStatusSlideBar.returnOrder(detail: detail)),
      ),
    );
    await tester.pump();

    printTestLog('slide button → expected: absent, actual: ${find.byType(SlideToConfirmButton).evaluate().length}');
    expect(find.byType(SlideToConfirmButton), findsNothing);

    // Let the in-flight request finish so it doesn't leak into the next test.
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('confirming sends the next status for this request', (
    tester,
  ) async {
    printTestDivider('confirming sends the next status for this request');
    detail.status = 5;
    await pumpButton(tester, detail);
    await slideToConfirm(tester);

    final update = adapter.requests.firstWhere(
      (r) => r.path == ApiEndpoints.returnRequestStatusUpdate,
    );
    final body = update.data as Map;
    printTestLog('return request id sent → expected: "${detail.id}", actual: "${body['id']}"');
    expect(body['id'], '${detail.id}');
    printTestLog('status sent → expected: "6", actual: "${body['status']}"');
    expect(body['status'], '6');
  });

  testWidgets('reloads the return detail after a successful update', (
    tester,
  ) async {
    printTestDivider('reloads the return detail after a successful update');
    detail.status = 5;
    await pumpButton(tester, detail);
    await slideToConfirm(tester);

    verify(() => detailCubit.loadDetail(any())).called(1);
    printTestLog('detail reloaded → verified');
  });
}
