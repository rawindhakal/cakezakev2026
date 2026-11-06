import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/core/localization/language_label_key.dart';
import 'package:deliveryboy/features/chat/models/chat_message.dart';
import 'package:deliveryboy/features/chat/widgets/attachment_preview.dart';
import 'package:deliveryboy/features/chat/widgets/chat_input_bar.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

/// The record/pick paths (`AudioRecorder`, `ImagePicker`, `FilePicker`) all
/// sit behind platform channels that throw `MissingPluginException` under
/// `flutter test`, so these tests exercise everything up to — but not
/// through — those calls: the typed-text send path, the enabled gate, the
/// icon the action button shows, and the menus the two icon buttons open.
void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  late List<({String text, ChatAttachment? attachment})> sent;

  setUp(() => sent = []);

  Future<void> pumpBar(WidgetTester tester, {bool enabled = true}) async {
    await tester.pumpWidget(
      pumpTestWidget(
        Align(
          alignment: Alignment.bottomCenter,
          child: ChatInputBar(
            enabled: enabled,
            onSend: (text, {attachment}) =>
                sent.add((text: text, attachment: attachment)),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder iconWithPath(String path) =>
      find.byWidgetPredicate((w) => w is AppSvgIcon && w.path == path);

  testWidgets('shows the hint and the microphone action while empty', (tester) async {
    printTestDivider('ChatInputBar shows the hint and the microphone action while empty');
    await pumpBar(tester);

    // Translations aren't loaded under `flutter test`, so translate() returns
    // the raw key.
    printTestLog('hint → expected: "${LanguageLabelKeys.typeAMessage}" visible');
    expect(find.text(LanguageLabelKeys.typeAMessage), findsOneWidget);
    printTestLog(
      'action icon → expected: microphone, actual: ${iconWithPath(AssetsConstants.microphoneIcon).evaluate().length} found',
    );
    expect(iconWithPath(AssetsConstants.microphoneIcon), findsOneWidget);
    printTestLog('send icon → expected: absent');
    expect(iconWithPath(AssetsConstants.sendIcon), findsNothing);
  });

  testWidgets('typing swaps the microphone for the send action', (tester) async {
    printTestDivider('ChatInputBar typing swaps the microphone for the send action');
    await pumpBar(tester);

    await tester.enterText(find.byType(TextField), 'On my way');
    // Two bounded pumps: the first runs the 180ms AnimatedSwitcher, the
    // second lets it drop the outgoing icon from the tree.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    printTestLog('send icon → expected: present');
    expect(iconWithPath(AssetsConstants.sendIcon), findsOneWidget);
    printTestLog('microphone icon → expected: absent');
    expect(iconWithPath(AssetsConstants.microphoneIcon), findsNothing);
  });

  testWidgets('whitespace alone does not arm the send action', (tester) async {
    printTestDivider('ChatInputBar whitespace alone does not arm the send action');
    await pumpBar(tester);

    await tester.enterText(find.byType(TextField), '    ');
    await tester.pump(const Duration(milliseconds: 200));

    printTestLog('microphone icon → expected: still present');
    expect(iconWithPath(AssetsConstants.microphoneIcon), findsOneWidget);
  });

  testWidgets('tapping send reports the trimmed text and clears the field', (tester) async {
    printTestDivider('ChatInputBar tapping send reports the trimmed text and clears the field');
    await pumpBar(tester);

    await tester.enterText(find.byType(TextField), '  On my way  ');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(iconWithPath(AssetsConstants.sendIcon));
    await tester.pump(const Duration(milliseconds: 200));

    printTestLog('sent → expected: 1 message, actual: ${sent.length}');
    expect(sent.length, 1);
    printTestLog('text → expected: "On my way", actual: "${sent.single.text}"');
    expect(sent.single.text, 'On my way');
    printTestLog('attachment → expected: null, actual: ${sent.single.attachment}');
    expect(sent.single.attachment, isNull);

    printTestLog(
      'field text → expected: "", actual: "${tester.widget<TextField>(find.byType(TextField)).controller?.text}"',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '',
    );
    printTestLog('action icon → expected: back to microphone');
    expect(iconWithPath(AssetsConstants.microphoneIcon), findsOneWidget);
  });

  testWidgets('a disabled bar ignores the send tap', (tester) async {
    printTestDivider('ChatInputBar a disabled bar ignores the send tap');
    await pumpBar(tester, enabled: false);

    await tester.enterText(find.byType(TextField), 'On my way');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(iconWithPath(AssetsConstants.sendIcon));
    await tester.pump(const Duration(milliseconds: 200));

    printTestLog('sent → expected: 0, actual: ${sent.length}');
    expect(sent, isEmpty);
    printTestLog(
      'field text → expected: kept, actual: "${tester.widget<TextField>(find.byType(TextField)).controller?.text}"',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'On my way',
    );
  });

  testWidgets('no attachment preview bar is shown until something is picked', (tester) async {
    printTestDivider('ChatInputBar no attachment preview bar is shown until something is picked');
    await pumpBar(tester);

    printTestLog(
      'preview bar → expected: none, actual: ${find.byType(AttachmentPreviewBar).evaluate().length}',
    );
    expect(find.byType(AttachmentPreviewBar), findsNothing);
  });

  testWidgets('the attachment button opens the camera/gallery/file menu', (tester) async {
    printTestDivider('ChatInputBar the attachment button opens the camera/gallery/file menu');
    await pumpBar(tester);

    await tester.tap(iconWithPath(AssetsConstants.attachmentIcon));
    // Bounded pump — the sheet's options run a staggered slide animation.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    printTestLog('camera → expected: "${LanguageLabelKeys.camera}" visible');
    expect(find.text(LanguageLabelKeys.camera), findsOneWidget);
    printTestLog('gallery → expected: "${LanguageLabelKeys.gallery}" visible');
    expect(find.text(LanguageLabelKeys.gallery), findsOneWidget);
    printTestLog('file → expected: "${LanguageLabelKeys.file}" visible');
    expect(find.text(LanguageLabelKeys.file), findsOneWidget);

    // Leave nothing mounted: the sheet keeps its animation controller alive.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the emoji button toggles the picker and the keyboard icon', (tester) async {
    printTestDivider('ChatInputBar the emoji button toggles the picker and the keyboard icon');
    await pumpBar(tester);

    await tester.tap(iconWithPath(AssetsConstants.emojiIcon));
    await tester.pump(const Duration(milliseconds: 200));

    printTestLog('keyboard icon → expected: present (picker open)');
    expect(iconWithPath(AssetsConstants.keyboardIcon), findsOneWidget);
    printTestLog('emoji icon → expected: absent');
    expect(iconWithPath(AssetsConstants.emojiIcon), findsNothing);

    await tester.tap(iconWithPath(AssetsConstants.keyboardIcon));
    await tester.pump(const Duration(milliseconds: 200));

    printTestLog('emoji icon → expected: back');
    expect(iconWithPath(AssetsConstants.emojiIcon), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
