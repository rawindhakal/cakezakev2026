import 'dart:io';

import 'package:deliveryboy/commons/widgets/profile_avatar_picker.dart';
import 'package:deliveryboy/features/profile/widgets/edit_profile_step_indicator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  testWidgets('passes image/imageUrl/onPicked/size through to ProfileAvatarPicker unchanged', (
    tester,
  ) async {
    printTestDivider(
      'EditProfileStepIndicator passes props through to ProfileAvatarPicker',
    );
    var picked = false;
    await tester.pumpWidget(
      pumpTestWidget(
        EditProfileStepIndicator(
          currentStep: 0,
          profileImage: null,
          profileImageUrl: 'https://example.com/avatar.webp',
          onProfileImagePicked: (_) => picked = true,
        ),
      ),
    );

    final avatar = tester.widget<ProfileAvatarPicker>(
      find.byType(ProfileAvatarPicker),
    );
    printTestLog('image → expected: null, actual: ${avatar.image}');
    expect(avatar.image, isNull);
    printTestLog(
      'imageUrl → expected: "https://example.com/avatar.webp", actual: "${avatar.imageUrl}"',
    );
    expect(avatar.imageUrl, 'https://example.com/avatar.webp');
    printTestLog('size → expected: 88, actual: ${avatar.size}');
    expect(avatar.size, 88);

    avatar.onPicked(File('dummy.png'));
    printTestLog('onPicked forwarded → expected: true, actual: $picked');
    expect(picked, isTrue);
  });
}
