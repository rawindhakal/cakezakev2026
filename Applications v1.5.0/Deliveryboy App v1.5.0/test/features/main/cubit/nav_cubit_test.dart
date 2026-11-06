import 'package:bloc_test/bloc_test.dart';
import 'package:deliveryboy/features/main/cubit/nav_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_logging.dart';

/// NavCubit is the whole of the main feature's state: one int, one setter.
/// Its one non-obvious property is that `NavState` is a plain class with no
/// `==` override, so every `changeTab` emits — even one that re-selects the
/// tab already showing. `MainScreen`'s `PopScope` relies on that: the back
/// gesture calls `changeTab(0)` and needs the rebuild to land.
void main() {
  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  test('starts on the first tab', () {
    printTestDivider('NavCubit starts on the first tab');
    final cubit = NavCubit();

    printTestLog(
      'currentIndex → expected: 0, actual: ${cubit.state.currentIndex}',
    );
    expect(cubit.state.currentIndex, 0);
    cubit.close();
  });

  blocTest<NavCubit, NavState>(
    'changeTab emits the selected index',
    build: NavCubit.new,
    act: (cubit) => cubit.changeTab(2),
    verify: (cubit) {
      printTestDivider('NavCubit changeTab emits the selected index');
      printTestLog(
        'currentIndex → expected: 2, actual: ${cubit.state.currentIndex}',
      );
      expect(cubit.state.currentIndex, 2);
    },
  );

  blocTest<NavCubit, NavState>(
    'every tab switch emits, in order',
    build: NavCubit.new,
    act: (cubit) {
      cubit.changeTab(1);
      cubit.changeTab(3);
      cubit.changeTab(0);
    },
    verify: (cubit) {
      printTestDivider('NavCubit every tab switch emits, in order');
      printTestLog('final index → expected: 0, actual: ${cubit.state.currentIndex}');
      expect(cubit.state.currentIndex, 0);
    },
    expect: () => [
      isA<NavState>().having((s) => s.currentIndex, 'currentIndex', 1),
      isA<NavState>().having((s) => s.currentIndex, 'currentIndex', 3),
      isA<NavState>().having((s) => s.currentIndex, 'currentIndex', 0),
    ],
  );

  blocTest<NavCubit, NavState>(
    're-selecting the current tab still emits (NavState has no value equality)',
    build: NavCubit.new,
    act: (cubit) {
      cubit.changeTab(1);
      cubit.changeTab(1);
    },
    expect: () => [
      isA<NavState>().having((s) => s.currentIndex, 'currentIndex', 1),
      isA<NavState>().having((s) => s.currentIndex, 'currentIndex', 1),
    ],
  );

  blocTest<NavCubit, NavState>(
    'changeTab(0) from the initial state emits rather than being deduped',
    build: NavCubit.new,
    act: (cubit) => cubit.changeTab(0),
    expect: () => [
      isA<NavState>().having((s) => s.currentIndex, 'currentIndex', 0),
    ],
  );
}
