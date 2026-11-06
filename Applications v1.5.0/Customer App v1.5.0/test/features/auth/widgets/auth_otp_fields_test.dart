import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinput/pinput.dart';
import 'package:customer/features/auth/widgets/auth_otp_fields.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  testWidgets('renders a 6-length Pinput with digits-only input', (tester) async {
    printTestDivider('AuthOtpFields renders a 6-length Pinput with digits-only input');
    final controller = TextEditingController();

    await tester.pumpWidget(
      pumpTestWidget(AuthOtpFields(controller: controller)),
    );

    final pinput = tester.widget<Pinput>(find.byType(Pinput));
    printTestLog('length → expected: 6, actual: ${pinput.length}');
    expect(pinput.length, 6);
  });

  testWidgets('onChanged fires as digits are typed', (tester) async {
    printTestDivider('AuthOtpFields onChanged fires as digits are typed');
    final controller = TextEditingController();
    String? lastChanged;

    await tester.pumpWidget(
      pumpTestWidget(
        AuthOtpFields(
          controller: controller,
          onChanged: (v) => lastChanged = v,
        ),
      ),
    );

    await tester.enterText(find.byType(Pinput), '1');
    await tester.pump();

    printTestLog('lastChanged → expected: "1", actual: "$lastChanged"');
    expect(lastChanged, '1');
  });

  testWidgets('onCompleted fires once all 6 digits are entered', (tester) async {
    printTestDivider('AuthOtpFields onCompleted fires once all 6 digits are entered');
    final controller = TextEditingController();
    String? completedValue;

    await tester.pumpWidget(
      pumpTestWidget(
        AuthOtpFields(
          controller: controller,
          onCompleted: (v) => completedValue = v,
        ),
      ),
    );

    await tester.enterText(find.byType(Pinput), '123456');
    await tester.pump();

    printTestLog('completedValue → expected: "123456", actual: "$completedValue"');
    expect(completedValue, '123456');
  });
}
