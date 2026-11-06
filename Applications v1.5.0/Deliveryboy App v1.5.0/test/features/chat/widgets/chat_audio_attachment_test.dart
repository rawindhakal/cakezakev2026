import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/commons/widgets/app_svg_icon.dart';
import 'package:deliveryboy/core/constants/assets_constants.dart';
import 'package:deliveryboy/features/chat/models/chat_message.dart';
import 'package:deliveryboy/features/chat/widgets/chat_audio_attachment.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

/// `audioplayers`'s method/event channels aren't mocked here — under
/// `flutter test` they fail silently (uncaught inside the plugin's own
/// internals, same as `chat_bubble_test.dart` already relies on for
/// rendering this widget), so `_preload`/`_togglePlay` never actually reach
/// a platform, `_duration` stays `Duration.zero`, and the state never
/// advances past `stopped`. These tests exercise what's reachable without a
/// real player: the initial render, both `isMe` colour branches, and that
/// tapping play doesn't throw.
void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  Future<void> pumpAttachment(
    WidgetTester tester,
    ChatAttachment attachment, {
    bool isMe = false,
  }) async {
    await tester.pumpWidget(
      pumpTestWidget(ChatAudioAttachment(attachment: attachment, isMe: isMe)),
    );
    await tester.pump();
  }

  const attachment = ChatAttachment(
    remoteUrl: 'https://cdn.test/voice.m4a',
    type: AttachmentType.audio,
  );

  testWidgets('renders the play icon and a zero/zero elapsed time before anything loads', (tester) async {
    printTestDivider('ChatAudioAttachment renders the play icon and a zero/zero elapsed time before anything loads');
    await pumpAttachment(tester, attachment);

    printTestLog('play icon → expected: present');
    expect(
      find.byWidgetPredicate(
        (w) => w is AppSvgIcon && w.path == AssetsConstants.playIcon,
      ),
      findsOneWidget,
    );
    printTestLog('pause icon → expected: absent');
    expect(
      find.byWidgetPredicate(
        (w) => w is AppSvgIcon && w.path == AssetsConstants.pauseIcon,
      ),
      findsNothing,
    );
    printTestLog('elapsed label → expected: "00:00" visible');
    expect(find.text('00:00'), findsOneWidget);
  });

  testWidgets('renders a progress bar', (tester) async {
    printTestDivider('ChatAudioAttachment renders a progress bar');
    await pumpAttachment(tester, attachment);

    printTestLog(
      'LinearProgressIndicator → expected: 1, actual: ${find.byType(LinearProgressIndicator).evaluate().length}',
    );
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    printTestLog('value → expected: 0.0 (no duration yet), actual: ${bar.value}');
    expect(bar.value, 0.0);
  });

  testWidgets('an outgoing (isMe) bubble tints the play icon with onPrimary', (tester) async {
    printTestDivider('ChatAudioAttachment an outgoing (isMe) bubble tints the play icon with onPrimary');
    await pumpAttachment(tester, attachment, isMe: true);

    final icon = tester.widget<AppSvgIcon>(
      find.byWidgetPredicate(
        (w) => w is AppSvgIcon && w.path == AssetsConstants.playIcon,
      ),
    );
    final scheme = Theme.of(
      tester.element(find.byType(ChatAudioAttachment)),
    ).colorScheme;
    printTestLog('colour → expected: ${scheme.onPrimary}, actual: ${icon.color}');
    expect(icon.color, scheme.onPrimary);
  });

  testWidgets('an incoming bubble tints the play icon with primary', (tester) async {
    printTestDivider('ChatAudioAttachment an incoming bubble tints the play icon with primary');
    await pumpAttachment(tester, attachment, isMe: false);

    final icon = tester.widget<AppSvgIcon>(
      find.byWidgetPredicate(
        (w) => w is AppSvgIcon && w.path == AssetsConstants.playIcon,
      ),
    );
    final scheme = Theme.of(
      tester.element(find.byType(ChatAudioAttachment)),
    ).colorScheme;
    printTestLog('colour → expected: ${scheme.primary}, actual: ${icon.color}');
    expect(icon.color, scheme.primary);
  });

  testWidgets('tapping the play button does not throw', (tester) async {
    printTestDivider('ChatAudioAttachment tapping the play button does not throw');
    await pumpAttachment(tester, attachment);

    await tester.tap(find.byType(GestureDetector).first);
    await tester.pump();

    printTestLog('exception → expected: none, actual: ${tester.takeException()}');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a local-only attachment with a nonexistent path still renders without throwing', (tester) async {
    printTestDivider('ChatAudioAttachment a local-only attachment with a nonexistent path still renders without throwing');
    await pumpAttachment(
      tester,
      const ChatAttachment(
        localPath: '/tmp/never-recorded.m4a',
        type: AttachmentType.audio,
      ),
    );

    printTestLog('exception → expected: none, actual: ${tester.takeException()}');
    expect(tester.takeException(), isNull);
    expect(find.byType(ChatAudioAttachment), findsOneWidget);
  });
}
