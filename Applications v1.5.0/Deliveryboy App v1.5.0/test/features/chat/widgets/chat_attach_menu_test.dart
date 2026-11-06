import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/chat/widgets/chat_attach_menu.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  late bool cameraTapped;
  late bool galleryTapped;
  late bool fileTapped;

  setUp(() {
    cameraTapped = false;
    galleryTapped = false;
    fileTapped = false;
  });

  Future<void> pumpMenu(WidgetTester tester) async {
    await tester.pumpWidget(
      pumpTestWidget(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showChatAttachMenu(
              context,
              onCamera: () => cameraTapped = true,
              onGallery: () => galleryTapped = true,
              onFile: () => fileTapped = true,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    // Bounded pumps — the sheet's options run a staggered slide animation.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Finder iconWithPath(String path) =>
      find.byWidgetPredicate((w) => w is AppSvgIcon && w.path == path);

  testWidgets('shows the camera, gallery and file options with the attachment title', (tester) async {
    printTestDivider('showChatAttachMenu shows the camera, gallery and file options with the attachment title');
    await pumpMenu(tester);

    printTestLog('title → expected: "${LanguageLabelKeys.attachment}" visible');
    expect(find.text(LanguageLabelKeys.attachment), findsOneWidget);
    printTestLog('camera label → expected: "${LanguageLabelKeys.camera}" visible');
    expect(find.text(LanguageLabelKeys.camera), findsOneWidget);
    printTestLog('gallery label → expected: "${LanguageLabelKeys.gallery}" visible');
    expect(find.text(LanguageLabelKeys.gallery), findsOneWidget);
    printTestLog('file label → expected: "${LanguageLabelKeys.file}" visible');
    expect(find.text(LanguageLabelKeys.file), findsOneWidget);

    printTestLog('camera icon → expected: present');
    expect(iconWithPath(AssetsConstants.cameraIcon), findsOneWidget);
    printTestLog('gallery icon → expected: present');
    expect(iconWithPath(AssetsConstants.galleryIcon), findsOneWidget);
    printTestLog('file icon → expected: present');
    expect(iconWithPath(AssetsConstants.fileIcon), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('tapping camera fires onCamera only', (tester) async {
    printTestDivider('showChatAttachMenu tapping camera fires onCamera only');
    await pumpMenu(tester);

    await tester.tap(find.text(LanguageLabelKeys.camera));
    await tester.pump();

    printTestLog('camera → expected: true, actual: $cameraTapped');
    expect(cameraTapped, isTrue);
    printTestLog('gallery → expected: false, actual: $galleryTapped');
    expect(galleryTapped, isFalse);
    printTestLog('file → expected: false, actual: $fileTapped');
    expect(fileTapped, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('tapping gallery fires onGallery only', (tester) async {
    printTestDivider('showChatAttachMenu tapping gallery fires onGallery only');
    await pumpMenu(tester);

    await tester.tap(find.text(LanguageLabelKeys.gallery));
    await tester.pump();

    printTestLog('gallery → expected: true, actual: $galleryTapped');
    expect(galleryTapped, isTrue);
    printTestLog('camera → expected: false, actual: $cameraTapped');
    expect(cameraTapped, isFalse);
    printTestLog('file → expected: false, actual: $fileTapped');
    expect(fileTapped, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('tapping file fires onFile only', (tester) async {
    printTestDivider('showChatAttachMenu tapping file fires onFile only');
    await pumpMenu(tester);

    await tester.tap(find.text(LanguageLabelKeys.file));
    await tester.pump();

    printTestLog('file → expected: true, actual: $fileTapped');
    expect(fileTapped, isTrue);
    printTestLog('camera → expected: false, actual: $cameraTapped');
    expect(cameraTapped, isFalse);
    printTestLog('gallery → expected: false, actual: $galleryTapped');
    expect(galleryTapped, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
