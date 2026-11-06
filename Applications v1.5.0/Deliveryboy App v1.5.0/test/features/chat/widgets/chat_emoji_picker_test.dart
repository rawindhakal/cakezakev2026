// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:deliveryboy/features/chat/widgets/chat_emoji_picker.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  // EmojiPicker's initState reads its recently-used cache off
  // SharedPreferences on first build — without a mocked backing store that
  // read hangs on a real platform channel and leaves a pending Timer behind
  // when the widget tree is torn down at test end.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('renders the emoji picker in a 280px tall box wired to the given controller', (tester) async {
    printTestDivider('ChatEmojiPicker renders the emoji picker in a 280px tall box wired to the given controller');
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      pumpTestWidget(ChatEmojiPicker(controller: controller)),
    );
    // EmojiPicker's initState kicks off a `Future(() async {...})` (via
    // Timer.run) to read its recent-emoji cache off SharedPreferences —
    // give the fake clock enough advances to drain it, or a pending timer
    // trips the end-of-test invariant check.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    printTestLog(
      'EmojiPicker → expected: 1, actual: ${find.byType(EmojiPicker).evaluate().length}',
    );
    expect(find.byType(EmojiPicker), findsOneWidget);

    final box = tester.widget<SizedBox>(
      find
          .ancestor(of: find.byType(EmojiPicker), matching: find.byType(SizedBox))
          .first,
    );
    printTestLog('height → expected: 280, actual: ${box.height}');
    expect(box.height, 280);

    final picker = tester.widget<EmojiPicker>(find.byType(EmojiPicker));
    printTestLog(
      'textEditingController → expected: same instance, actual: ${identical(picker.textEditingController, controller)}',
    );
    expect(picker.textEditingController, same(controller));
  });

  testWidgets('does not throw when built without a pre-existing search bar state', (tester) async {
    printTestDivider('ChatEmojiPicker does not throw when built without a pre-existing search bar state');
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      pumpTestWidget(ChatEmojiPicker(controller: controller)),
    );
    // EmojiPicker's initState kicks off a `Future(() async {...})` (via
    // Timer.run) to read its recent-emoji cache off SharedPreferences —
    // give the fake clock enough advances to drain it, or a pending timer
    // trips the end-of-test invariant check.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    printTestLog('exception → expected: none, actual: ${tester.takeException()}');
    expect(tester.takeException(), isNull);
  });
}
