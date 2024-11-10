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

  test('Integration Test - Timer Completes', () async {
    // Wait for "Get ready" text
    print('Waiting for "Get ready" text');
    await driver!
        .waitFor(find.text('Get ready'), timeout: const Duration(seconds: 5));

    // Proceed to next state
    print('Waiting for "Warmup" text');
    await Future.delayed(const Duration(seconds: 5));
    await driver!
        .waitFor(find.text('Warmup'), timeout: const Duration(seconds: 5));

    // Check for next state
    print('Waiting for "Work" text');
    await Future.delayed(const Duration(seconds: 5));
    await driver!
        .waitFor(find.text('Work'), timeout: const Duration(seconds: 5));

    // Check for next state
    print('Waiting for "Rest" text');
    await Future.delayed(const Duration(seconds: 5));
    await driver!
        .waitFor(find.text('Rest'), timeout: const Duration(seconds: 5));

    // Check for next state
    print('Waiting for "Cooldown" text');
    await Future.delayed(const Duration(seconds: 5));
    await driver!
        .waitFor(find.text('Cooldown'), timeout: const Duration(seconds: 5));

    // Check for next state
    print('Waiting for "End" text');
    await Future.delayed(const Duration(seconds: 5));
    await driver!
        .waitFor(find.text('End'), timeout: const Duration(seconds: 5));

    // Find and tap the restart icon.
    print('Tapping restart icon');
    final restartIcon = find.byTooltip('Restart');
    await driver!.tap(restartIcon);
  });
}