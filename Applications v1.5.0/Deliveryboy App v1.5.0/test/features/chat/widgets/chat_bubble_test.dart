import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/commons/widgets/shimmer_loading.dart';
import 'package:deliveryboy/core/api/hive_box_keys.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/features/chat/models/chat_message.dart';
import 'package:deliveryboy/features/chat/widgets/chat_audio_attachment.dart';
import 'package:deliveryboy/features/chat/widgets/chat_bubble.dart';
import 'package:deliveryboy/features/chat/widgets/chat_file_attachment.dart';
import 'package:deliveryboy/features/chat/widgets/chat_image_attachment.dart';
import 'package:deliveryboy/features/chat/widgets/chat_status_icon.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../helpers/hive_test_helper.dart';
import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    // The bubble's timestamp goes through AppDateFormatter, which reads the
    // country settings' time format out of SettingsHiveBox.
    await HiveTestHelper.setUp(authBox);
    await Hive.openBox(settingsBox);
    tempDir = Directory.systemTemp.createTempSync('chat_bubble_test_');
  });

  tearDown(() async {
    tempDir.deleteSync(recursive: true);
    await Hive.box(settingsBox).close();
    await Hive.deleteBoxFromDisk(settingsBox);
    await HiveTestHelper.tearDown(authBox);
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  ChatMessage message({
    String text = 'Five minutes away.',
    bool isMe = false,
    MessageStatus status = MessageStatus.sent,
    ChatAttachment? attachment,
  }) => ChatMessage(
    id: '901',
    senderId: isMe ? 12 : 88,
    senderType: isMe ? 'delivery_boy' : 'user',
    message: text,
    timestamp: DateTime(2026, 8, 19, 9, 10),
    isMe: isMe,
    status: status,
    attachment: attachment,
  );

  Future<void> pumpBubble(WidgetTester tester, ChatMessage msg) async {
    await tester.pumpWidget(pumpTestWidget(ChatBubble(message: msg)));
    await tester.pump();
  }

  Alignment alignmentOf(WidgetTester tester) => tester
      .widget<Align>(
        find
            .descendant(of: find.byType(ChatBubble), matching: find.byType(Align))
            .first,
      )
      .alignment
      as Alignment;

  group('ChatBubble', () {
    testWidgets('renders the message text', (tester) async {
      printTestDivider('ChatBubble renders the message text');
      await pumpBubble(tester, message());

      printTestLog('text → expected: "Five minutes away." visible');
      expect(find.text('Five minutes away.'), findsOneWidget);
    });

    testWidgets('an incoming message hugs the start edge', (tester) async {
      printTestDivider('ChatBubble an incoming message hugs the start edge');
      await pumpBubble(tester, message(isMe: false));

      final alignment = alignmentOf(tester);
      printTestLog('alignment → expected: centerLeft, actual: $alignment');
      expect(alignment, Alignment.centerLeft);
    });

    testWidgets('an outgoing message hugs the end edge', (tester) async {
      printTestDivider('ChatBubble an outgoing message hugs the end edge');
      await pumpBubble(tester, message(isMe: true));

      final alignment = alignmentOf(tester);
      printTestLog('alignment → expected: centerRight, actual: $alignment');
      expect(alignment, Alignment.centerRight);
    });

    testWidgets('a delivery status icon shows only on my own messages', (tester) async {
      printTestDivider('ChatBubble a delivery status icon shows only on my own messages');
      await pumpBubble(tester, message(isMe: true));
      printTestLog(
        'mine → expected: 1 status icon, actual: ${find.byType(ChatStatusIcon).evaluate().length}',
      );
      expect(find.byType(ChatStatusIcon), findsOneWidget);
    });

    testWidgets('an incoming message carries no delivery status icon', (tester) async {
      printTestDivider('ChatBubble an incoming message carries no delivery status icon');
      await pumpBubble(tester, message(isMe: false));
      printTestLog(
        'theirs → expected: none, actual: ${find.byType(ChatStatusIcon).evaluate().length}',
      );
      expect(find.byType(ChatStatusIcon), findsNothing);
    });

    testWidgets('an image attachment renders the image view', (tester) async {
      printTestDivider('ChatBubble an image attachment renders the image view');
      await pumpBubble(
        tester,
        message(
          text: '',
          attachment: const ChatAttachment(
            remoteUrl: 'https://cdn.test/gate.jpg',
            fileName: 'gate.jpg',
            type: AttachmentType.image,
          ),
        ),
      );

      printTestLog(
        'image view → expected: 1, actual: ${find.byType(ChatImageAttachment).evaluate().length}',
      );
      expect(find.byType(ChatImageAttachment), findsOneWidget);
      printTestLog(
        'file view → expected: none, actual: ${find.byType(ChatFileAttachment).evaluate().length}',
      );
      expect(find.byType(ChatFileAttachment), findsNothing);
    });

    testWidgets('an audio attachment renders the audio player view', (tester) async {
      printTestDivider('ChatBubble an audio attachment renders the audio player view');
      await pumpBubble(
        tester,
        message(
          text: '',
          attachment: const ChatAttachment(
            remoteUrl: 'https://cdn.test/voice.m4a',
            fileName: 'voice.m4a',
            type: AttachmentType.audio,
          ),
        ),
      );

      printTestLog(
        'audio view → expected: 1, actual: ${find.byType(ChatAudioAttachment).evaluate().length}',
      );
      expect(find.byType(ChatAudioAttachment), findsOneWidget);
    });

    testWidgets('a document attachment renders the file row with its name', (tester) async {
      printTestDivider('ChatBubble a document attachment renders the file row with its name');
      await pumpBubble(
        tester,
        message(
          text: '',
          attachment: const ChatAttachment(
            remoteUrl: 'https://cdn.test/invoice.pdf',
            fileName: 'invoice.pdf',
            type: AttachmentType.file,
          ),
        ),
      );

      printTestLog(
        'file view → expected: 1, actual: ${find.byType(ChatFileAttachment).evaluate().length}',
      );
      expect(find.byType(ChatFileAttachment), findsOneWidget);
      printTestLog('file name → expected: "invoice.pdf" visible');
      expect(find.text('invoice.pdf'), findsOneWidget);
    });

    testWidgets('a caption is shown alongside its attachment', (tester) async {
      printTestDivider('ChatBubble a caption is shown alongside its attachment');
      await pumpBubble(
        tester,
        message(
          text: 'Left at the gate',
          attachment: const ChatAttachment(
            remoteUrl: 'https://cdn.test/gate.jpg',
            type: AttachmentType.image,
          ),
        ),
      );

      printTestLog('caption → expected: "Left at the gate" visible');
      expect(find.text('Left at the gate'), findsOneWidget);
    });

    testWidgets('an attachment-only message renders no empty text row', (tester) async {
      printTestDivider('ChatBubble an attachment-only message renders no empty text row');
      final file = File('${tempDir.path}/invoice.pdf')..writeAsStringSync('x');
      await pumpBubble(
        tester,
        message(
          text: '',
          attachment: ChatAttachment(
            localPath: file.path,
            fileName: 'invoice.pdf',
            type: AttachmentType.file,
          ),
        ),
      );

      printTestLog('empty text → expected: none, actual: ${find.text('').evaluate().length}');
      expect(find.text(''), findsNothing);
    });
  });

  group('ChatStatusIcon', () {
    Future<void> pumpIcon(WidgetTester tester, MessageStatus status) async {
      await tester.pumpWidget(pumpTestWidget(ChatStatusIcon(status: status)));
      await tester.pump();
    }

    testWidgets('sending shows a spinner rather than a tick', (tester) async {
      printTestDivider('ChatStatusIcon sending shows a spinner rather than a tick');
      await pumpIcon(tester, MessageStatus.sending);

      printTestLog(
        'spinner → expected: 1, actual: ${find.byType(ShimmerInline).evaluate().length}',
      );
      expect(find.byType(ShimmerInline), findsOneWidget);
    });

    testWidgets('sent shows the read-check icon', (tester) async {
      printTestDivider('ChatStatusIcon sent shows the read-check icon');
      await pumpIcon(tester, MessageStatus.sent);

      final icon = tester.widget<AppSvgIcon>(find.byType(AppSvgIcon));
      printTestLog(
        'path → expected: ${AssetsConstants.checkReadIcon}, actual: ${icon.path}',
      );
      expect(icon.path, AssetsConstants.checkReadIcon);
    });

    testWidgets('failed shows the error icon in the error colour', (tester) async {
      printTestDivider('ChatStatusIcon failed shows the error icon in the error colour');
      await pumpIcon(tester, MessageStatus.failed);

      final icon = tester.widget<AppSvgIcon>(find.byType(AppSvgIcon));
      printTestLog(
        'path → expected: ${AssetsConstants.infoCircleIcon}, actual: ${icon.path}',
      );
      expect(icon.path, AssetsConstants.infoCircleIcon);
      final scheme = Theme.of(
        tester.element(find.byType(ChatStatusIcon)),
      ).colorScheme;
      printTestLog('colour → expected: ${scheme.error}, actual: ${icon.color}');
      expect(icon.color, scheme.error);
    });
  });
}
