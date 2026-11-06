import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/chat/models/chat_message.dart';
import 'package:deliveryboy/features/chat/widgets/attachment_preview.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('attachment_preview_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  var removed = false;

  setUp(() => removed = false);

  Future<void> pumpBar(WidgetTester tester, ChatAttachment attachment) async {
    await tester.pumpWidget(
      pumpTestWidget(
        AttachmentPreviewBar(
          attachment: attachment,
          onRemove: () => removed = true,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('an image attachment shows the image label and photo-ready sublabel', (tester) async {
    printTestDivider('AttachmentPreviewBar an image attachment shows the image label and photo-ready sublabel');
    await pumpBar(
      tester,
      const ChatAttachment(
        remoteUrl: 'https://cdn.test/gate.jpg',
        fileName: 'gate.jpg',
        type: AttachmentType.image,
      ),
    );

    printTestLog('label → expected: "${LanguageLabelKeys.attachmentImage}" visible');
    expect(find.text(LanguageLabelKeys.attachmentImage), findsOneWidget);
    printTestLog('sublabel → expected: "${LanguageLabelKeys.attachmentPhotoReady}" visible');
    expect(find.text(LanguageLabelKeys.attachmentPhotoReady), findsOneWidget);
  });

  testWidgets('an audio attachment shows the voice-message label and voice-ready sublabel', (tester) async {
    printTestDivider('AttachmentPreviewBar an audio attachment shows the voice-message label and voice-ready sublabel');
    await pumpBar(
      tester,
      const ChatAttachment(
        remoteUrl: 'https://cdn.test/voice.m4a',
        type: AttachmentType.audio,
      ),
    );

    printTestLog('label → expected: "${LanguageLabelKeys.attachmentVoiceMessage}" visible');
    expect(find.text(LanguageLabelKeys.attachmentVoiceMessage), findsOneWidget);
    printTestLog('sublabel → expected: "${LanguageLabelKeys.attachmentVoiceReady}" visible');
    expect(find.text(LanguageLabelKeys.attachmentVoiceReady), findsOneWidget);
  });

  testWidgets('a file attachment shows its file name and the file-ready sublabel', (tester) async {
    printTestDivider('AttachmentPreviewBar a file attachment shows its file name and the file-ready sublabel');
    await pumpBar(
      tester,
      const ChatAttachment(
        remoteUrl: 'https://cdn.test/invoice.pdf',
        fileName: 'invoice.pdf',
        type: AttachmentType.file,
      ),
    );

    printTestLog('label → expected: "invoice.pdf" visible');
    expect(find.text('invoice.pdf'), findsOneWidget);
    printTestLog('sublabel → expected: "${LanguageLabelKeys.attachmentFileReady}" visible');
    expect(find.text(LanguageLabelKeys.attachmentFileReady), findsOneWidget);
  });

  testWidgets('a file attachment with no name falls back to the generic file label', (tester) async {
    printTestDivider('AttachmentPreviewBar a file attachment with no name falls back to the generic file label');
    await pumpBar(
      tester,
      const ChatAttachment(
        remoteUrl: 'https://cdn.test/blob',
        type: AttachmentType.file,
      ),
    );

    printTestLog('label → expected: "${LanguageLabelKeys.attachmentFile}" visible');
    expect(find.text(LanguageLabelKeys.attachmentFile), findsOneWidget);
  });

  testWidgets('tapping the close icon fires onRemove', (tester) async {
    printTestDivider('AttachmentPreviewBar tapping the close icon fires onRemove');
    await pumpBar(
      tester,
      const ChatAttachment(
        remoteUrl: 'https://cdn.test/gate.jpg',
        type: AttachmentType.image,
      ),
    );

    await tester.tap(find.byType(IconButton));
    await tester.pump();

    printTestLog('removed → expected: true, actual: $removed');
    expect(removed, isTrue);
  });

  testWidgets('a local image path renders an Image.file thumbnail instead of the icon tile', (tester) async {
    printTestDivider('AttachmentPreviewBar a local image path renders an Image.file thumbnail instead of the icon tile');
    final file = File('${tempDir.path}/gate.jpg')..writeAsBytesSync([0, 1, 2]);

    await pumpBar(
      tester,
      ChatAttachment(localPath: file.path, type: AttachmentType.image),
    );

    printTestLog(
      'Image.file → expected: 1, actual: ${find.byType(Image).evaluate().length}',
    );
    expect(find.byType(Image), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<FileImage>());
  });

  testWidgets('an image with no local path renders the icon tile, not Image.file', (tester) async {
    printTestDivider('AttachmentPreviewBar an image with no local path renders the icon tile, not Image.file');
    await pumpBar(
      tester,
      const ChatAttachment(
        remoteUrl: 'https://cdn.test/gate.jpg',
        type: AttachmentType.image,
      ),
    );

    printTestLog(
      'Image.file → expected: none, actual: ${find.byType(Image).evaluate().length}',
    );
    expect(find.byType(Image), findsNothing);
    printTestLog(
      'svg icon tile → expected: 2 (thumbnail + close button), actual: ${find.byType(AppSvgIcon).evaluate().length}',
    );
    expect(find.byType(AppSvgIcon), findsNWidgets(2));
  });

  testWidgets('an audio attachment uses the microphone icon for its thumbnail', (tester) async {
    printTestDivider('AttachmentPreviewBar an audio attachment uses the microphone icon for its thumbnail');
    await pumpBar(
      tester,
      const ChatAttachment(
        remoteUrl: 'https://cdn.test/voice.m4a',
        type: AttachmentType.audio,
      ),
    );

    final icons = tester
        .widgetList<AppSvgIcon>(find.byType(AppSvgIcon))
        .map((w) => w.path)
        .toList();
    printTestLog(
      'microphone icon → expected: present, actual: $icons',
    );
    expect(icons, contains(AssetsConstants.microphoneIcon));
  });

  testWidgets('a file attachment uses the file icon for its thumbnail', (tester) async {
    printTestDivider('AttachmentPreviewBar a file attachment uses the file icon for its thumbnail');
    await pumpBar(
      tester,
      const ChatAttachment(
        remoteUrl: 'https://cdn.test/invoice.pdf',
        fileName: 'invoice.pdf',
        type: AttachmentType.file,
      ),
    );

    final icons = tester
        .widgetList<AppSvgIcon>(find.byType(AppSvgIcon))
        .map((w) => w.path)
        .toList();
    printTestLog('file icon → expected: present, actual: $icons');
    expect(icons, contains(AssetsConstants.fileIcon));
  });
}
