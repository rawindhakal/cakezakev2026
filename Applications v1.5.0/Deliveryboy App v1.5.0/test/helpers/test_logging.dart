/// Prints a labeled divider before a test body's assertions, so a failing
/// `flutter test` run is scannable without re-reading the test source.
void printTestDivider(String label) {
  // ignore: avoid_print
  print('\n────────── $label ──────────');
}

/// Prints an expected-vs-actual line for a test assertion, so a failing
/// `flutter test` run is scannable without re-reading the test source.
void printTestLog(String message) {
  // ignore: avoid_print
  print(message);
}
