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
    await driver!
        .waitFor(find.text('Get ready'), timeout: const Duration(seconds: 10));

    // Proceed to next state with delay
    await Future.delayed(const Duration(seconds: 11));
    await driver!
        .waitFor(find.text('Warmup'), timeout: const Duration(seconds: 5));

    // Check for next state
    await Future.delayed(const Duration(seconds: 11));
    await driver!
        .waitFor(find.text('Work'), timeout: const Duration(seconds: 5));

    // Find and tap the restart icon.
    final restartIcon = find.byTooltip('Restart');
    await driver!.tap(restartIcon);

    // Wait for "Get ready" text
    await Future.delayed(const Duration(seconds: 5));
    await driver!
        .waitFor(find.text('Get ready'), timeout: const Duration(seconds: 10));
  });

  // test('Timer integration test', () async {
  //   // Wait until the text "Get ready" is found.
  //   await driver!.waitFor(find.text('Get ready'));

  //   // Wait for 11 seconds, assuming the timer updates automatically.
  //   await Future.delayed(const Duration(seconds: 11));

  //   // Check that the text has updated to "Warmup".
  //   expect(await driver!.getText(find.text('Warmup')), 'Warmup');

  //   // Wait for an additional 20 seconds.
  //   await Future.delayed(const Duration(seconds: 20));

  //   // Check that the text has updated to "Work".
  //   expect(await driver!.getText(find.text('Work')), 'Work');

  //   // Find and tap the restart icon.
  //   final restartIcon = find.byTooltip(
  //       'Restart'); // Ensure the icon has a tooltip for easier finding
  //   await driver!.tap(restartIcon);

  //   // Wait at most 10 seconds for "Get ready" to be back on screen.
  //   await driver!
  //       .waitFor(find.text('Get ready'), timeout: const Duration(seconds: 10));

  //   // Find and tap the "Stop" button.
  //   await driver!.tap(find.text('Stop'));
  // });
}
