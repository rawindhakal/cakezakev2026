import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/commons/widgets/app_image_upload_field.dart';
import 'package:deliveryboy/features/auth/widgets/register_identity_docs.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpSection(
    WidgetTester tester, {
    File? nationalIdImage,
    String? nationalIdError,
    File? drivingLicenseImage,
    String? drivingLicenseError,
    ValueChanged<File>? onNationalIdPicked,
    ValueChanged<File>? onDrivingLicensePicked,
  }) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      pumpTestWidget(
        IdentityDocsSection(
          nationalIdImage: nationalIdImage,
          nationalIdError: nationalIdError,
          onNationalIdPicked: onNationalIdPicked ?? (_) {},
          drivingLicenseImage: drivingLicenseImage,
          drivingLicenseError: drivingLicenseError,
          onDrivingLicensePicked: onDrivingLicensePicked ?? (_) {},
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders one upload field per document', (tester) async {
    printTestDivider('renders one upload field per document');
    await pumpSection(tester);

    printTestLog(
      'AppImageUploadField → expected: 2, actual: ${find.byType(AppImageUploadField).evaluate().length}',
    );
    expect(find.byType(AppImageUploadField), findsNWidgets(2));
  });

  testWidgets('shows no error text when neither document has an error', (
    tester,
  ) async {
    printTestDivider('shows no error text when neither document has an error');
    await pumpSection(tester);

    final fields = tester
        .widgetList<AppImageUploadField>(find.byType(AppImageUploadField))
        .toList();
    printTestLog('nationalId.errorText → expected: null, actual: ${fields[0].errorText}');
    expect(fields[0].errorText, isNull);
    printTestLog('drivingLicence.errorText → expected: null, actual: ${fields[1].errorText}');
    expect(fields[1].errorText, isNull);
  });

  testWidgets('renders each error message passed in', (tester) async {
    printTestDivider('renders each error message passed in');
    await pumpSection(
      tester,
      nationalIdError: 'national id required',
      drivingLicenseError: 'driving licence required',
    );

    // The message renders twice per document: once inside the upload field's
    // own error slot, once as the AppText below it.
    printTestLog(
      'national id error → expected: at least 1, actual: ${find.text('national id required').evaluate().length}',
    );
    expect(find.text('national id required'), findsWidgets);
    printTestLog(
      'driving licence error → expected: at least 1, actual: ${find.text('driving licence required').evaluate().length}',
    );
    expect(find.text('driving licence required'), findsWidgets);
  });

  testWidgets('forwards each picked file to the matching callback', (
    tester,
  ) async {
    printTestDivider('forwards each picked file to the matching callback');
    File? nationalId;
    File? drivingLicence;
    await pumpSection(
      tester,
      onNationalIdPicked: (f) => nationalId = f,
      onDrivingLicensePicked: (f) => drivingLicence = f,
    );

    // Driving the upload field's own onPicked rather than tapping it: a real
    // tap opens a camera/gallery sheet backed by the image_picker plugin,
    // which has no implementation under `flutter test`.
    final fields = tester
        .widgetList<AppImageUploadField>(find.byType(AppImageUploadField))
        .toList();
    fields[0].onPicked(File('/tmp/national-id.png'));
    fields[1].onPicked(File('/tmp/licence.png'));
    await tester.pump();

    printTestLog('nationalId path → expected: "/tmp/national-id.png", actual: "${nationalId?.path}"');
    expect(nationalId?.path, '/tmp/national-id.png');
    printTestLog('drivingLicence path → expected: "/tmp/licence.png", actual: "${drivingLicence?.path}"');
    expect(drivingLicence?.path, '/tmp/licence.png');
  });

  testWidgets('passes a selected image through to its upload field', (
    tester,
  ) async {
    printTestDivider('passes a selected image through to its upload field');
    final picked = File('/tmp/national-id.png');
    await pumpSection(tester, nationalIdImage: picked);

    final fields = tester
        .widgetList<AppImageUploadField>(find.byType(AppImageUploadField))
        .toList();
    printTestLog('nationalId.image → expected: "${picked.path}", actual: "${fields[0].image?.path}"');
    expect(fields[0].image?.path, picked.path);
    printTestLog('drivingLicence.image → expected: null, actual: ${fields[1].image}');
    expect(fields[1].image, isNull);
  });
}
