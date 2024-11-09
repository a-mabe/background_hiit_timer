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

  test('Timer integration test with timeout and debug', () async {
    // Wait for "Get ready" text
    print('Waiting for "Get ready" text');
    await driver!
        .waitFor(find.text('Get ready'), timeout: const Duration(seconds: 10));

    // Proceed to next state with delay
    await Future.delayed(const Duration(seconds: 11));
    print('Waiting for "Warmup" text');
    await driver!
        .waitFor(find.text('Warmup'), timeout: const Duration(seconds: 5));

    // Check for next state
    await Future.delayed(const Duration(seconds: 11));
    print('Waiting for "Work" text');
    await driver!
        .waitFor(find.text('Work'), timeout: const Duration(seconds: 5));

    // Find and tap the restart icon.
    print('Tapping restart icon');
    final restartIcon = find.byTooltip('Restart');
    await driver!.tap(restartIcon);

    // Wait for "Get ready" text
    await Future.delayed(const Duration(seconds: 5));
    print('Waiting for "Get ready" text');
    await driver!
        .waitFor(find.text('Get ready'), timeout: const Duration(seconds: 10));
  });
}
