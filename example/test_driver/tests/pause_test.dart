import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart';

void main() {
  FlutterDriver? driver;

  setUpAll(() async {
    driver = await FlutterDriver.connect();
  });

  tearDownAll(() async {
    if (driver != null) {
      await driver!.close();
    }
  });

  test('Integration Test - Timer Restart', () async {
    // Wait for "Get ready" text
    print('Waiting for "Get ready" text');
    await driver!
        .waitFor(find.text('Get ready'), timeout: const Duration(seconds: 10));

    // Find and tap the pause icon.
    print('Tapping pause icon');
    final pauseIcon = find.byTooltip('Pause');
    await driver!.tap(pauseIcon);

    // Ensure paused
    await Future.delayed(const Duration(seconds: 15));
    print('"Get ready" text should still be on screen');
    await driver!
        .waitFor(find.text('Get ready'), timeout: const Duration(seconds: 5));

    // Find and tap the pause icon.
    print('Tapping pause icon again to unpause');
    await driver!.tap(pauseIcon);
  }, timeout: const Timeout(Duration(minutes: 1)));
}
