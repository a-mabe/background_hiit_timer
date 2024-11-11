// test_driver/main_test.dart
import 'tests/complete_test.dart' as complete_test;
import 'tests/pause_test.dart' as pause_test;
import 'tests/skip_test.dart' as skip_test;

void main() {
  complete_test.main();
  skip_test.main();
  pause_test.main();
}
