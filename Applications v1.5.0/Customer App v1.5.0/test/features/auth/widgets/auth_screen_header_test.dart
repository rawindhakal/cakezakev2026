import 'package:flutter_test/flutter_test.dart';
import 'package:customer/features/auth/widgets/auth_screen_header.dart';

import '../../../helpers/pump_test_widget.dart';
import '../../../helpers/test_logging.dart';

void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  testWidgets('renders the title and subtitle it is given', (tester) async {
    printTestDivider('AuthScreenHeader renders the title and subtitle it is given');
    await tester.pumpWidget(
      pumpTestWidget(
        const AuthScreenHeader(title: 'Welcome back', subtitle: 'Sign in to continue'),
      ),
    );

    printTestLog('title → expected: present, actual: ${find.text('Welcome back').evaluate().isNotEmpty}');
    expect(find.text('Welcome back'), findsOneWidget);
    printTestLog(
      'subtitle → expected: present, actual: ${find.text('Sign in to continue').evaluate().isNotEmpty}',
    );
    expect(find.text('Sign in to continue'), findsOneWidget);
  });
}
