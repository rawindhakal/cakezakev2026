import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/commons/widgets/app_network_image.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/features/chat/models/chat_message.dart';
import 'package:deliveryboy/features/chat/widgets/chat_image_attachment.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('chat_image_attachment_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  Future<void> pumpAttachment(
    WidgetTester tester,
    ChatAttachment attachment, {
    bool isMe = false,
  }) async {
    await tester.pumpWidget(
      pumpTestWidget(ChatImageAttachment(attachment: attachment, isMe: isMe)),
    );
    await tester.pump();
  }

  testWidgets('a local file path renders Image.file, not the network view', (tester) async {
    printTestDivider('ChatImageAttachment a local file path renders Image.file, not the network view');
    final file = File('${tempDir.path}/gate.jpg')..writeAsBytesSync([0, 1, 2]);

    await pumpAttachment(
      tester,
      ChatAttachment(localPath: file.path, type: AttachmentType.image),
    );

    printTestLog(
      'Image → expected: 1, actual: ${find.byType(Image).evaluate().length}',
    );
    expect(find.byType(Image), findsOneWidget);
    printTestLog(
      'AppNetworkImage → expected: none, actual: ${find.byType(AppNetworkImage).evaluate().length}',
    );
    expect(find.byType(AppNetworkImage), findsNothing);
  });

  testWidgets('a remote url with no local path renders the network image view', (tester) async {
    printTestDivider('ChatImageAttachment a remote url with no local path renders the network image view');
    await pumpAttachment(
      tester,
      const ChatAttachment(
        remoteUrl: 'https://cdn.test/gate.jpg',
        type: AttachmentType.image,
      ),
    );

    printTestLog(
      'AppNetworkImage → expected: 1, actual: ${find.byType(AppNetworkImage).evaluate().length}',
    );
    expect(find.byType(AppNetworkImage), findsOneWidget);
    final img = tester.widget<AppNetworkImage>(find.byType(AppNetworkImage));
    printTestLog('url → expected: "https://cdn.test/gate.jpg", actual: "${img.url}"');
    expect(img.url, 'https://cdn.test/gate.jpg');
  });

  testWidgets('neither a local nor a remote source renders the broken-image fallback', (tester) async {
    printTestDivider('ChatImageAttachment neither a local nor a remote source renders the broken-image fallback');
    await pumpAttachment(
      tester,
      const ChatAttachment(type: AttachmentType.image),
    );

    printTestLog(
      'AppNetworkImage → expected: none, actual: ${find.byType(AppNetworkImage).evaluate().length}',
    );
    expect(find.byType(AppNetworkImage), findsNothing);
    printTestLog(
      'broken-image svg → expected: present, actual: ${find.byWidgetPredicate((w) => w is AppSvgIcon && w.path == AssetsConstants.fileBrokenIcon).evaluate().length}',
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is AppSvgIcon && w.path == AssetsConstants.fileBrokenIcon,
      ),
      findsOneWidget,
    );
  });

  testWidgets('a nonexistent local path falls through hasLocal=false to the broken fallback', (tester) async {
    printTestDivider('ChatImageAttachment a nonexistent local path falls through hasLocal=false to the broken fallback');
    // ChatAttachment.hasLocal checks File(...).existsSync() — a path that
    // was never written to disk does not count as local.
    await pumpAttachment(
      tester,
      ChatAttachment(
        localPath: '${tempDir.path}/never-written.jpg',
        type: AttachmentType.image,
      ),
    );

    printTestLog(
      'Image → expected: none, actual: ${find.byType(Image).evaluate().length}',
    );
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('tapping the image pushes the full-screen viewer', (tester) async {
    printTestDivider('ChatImageAttachment tapping the image pushes the full-screen viewer');
    await pumpAttachment(
      tester,
      const ChatAttachment(
        remoteUrl: 'https://cdn.test/gate.jpg',
        type: AttachmentType.image,
      ),
    );

    await tester.tap(find.byType(ChatImageAttachment));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    printTestLog(
      'ChatFullScreenImage → expected: 1, actual: ${find.byType(ChatFullScreenImage).evaluate().length}',
    );
    expect(find.byType(ChatFullScreenImage), findsOneWidget);
  });

  testWidgets('ChatFullScreenImage shows the network image for a remote attachment', (tester) async {
    printTestDivider('ChatFullScreenImage shows the network image for a remote attachment');
    await tester.pumpWidget(
      pumpTestWidget(
        const ChatFullScreenImage(
          attachment: ChatAttachment(
            remoteUrl: 'https://cdn.test/gate.jpg',
            type: AttachmentType.image,
          ),
        ),
        wrapInScaffold: false,
      ),
    );
    await tester.pump();

    printTestLog(
      'AppNetworkImage → expected: 1, actual: ${find.byType(AppNetworkImage).evaluate().length}',
    );
    expect(find.byType(AppNetworkImage), findsOneWidget);
    printTestLog(
      'InteractiveViewer → expected: 1, actual: ${find.byType(InteractiveViewer).evaluate().length}',
    );
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('ChatFullScreenImage shows the broken-image icon with neither source', (tester) async {
    printTestDivider('ChatFullScreenImage shows the broken-image icon with neither source');
    await tester.pumpWidget(
      pumpTestWidget(
        const ChatFullScreenImage(
          attachment: ChatAttachment(type: AttachmentType.image),
        ),
        wrapInScaffold: false,
      ),
    );
    await tester.pump();

    printTestLog(
      'broken-image svg → expected: present, actual: ${find.byWidgetPredicate((w) => w is AppSvgIcon && w.path == AssetsConstants.fileBrokenIcon).evaluate().length}',
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is AppSvgIcon && w.path == AssetsConstants.fileBrokenIcon,
      ),
      findsOneWidget,
    );
  });
}
