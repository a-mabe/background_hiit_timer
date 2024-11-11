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
    await driver!
        .waitFor(find.text('Get ready'), timeout: const Duration(seconds: 10));

    // Find and tap the skip next icon.
    final nextIcon = find.byTooltip('Skip Next');
    await driver!.tap(nextIcon);

    // Tap the skip next icon again.
    await driver!.tap(nextIcon);

    // Get ready and Warmup skipped, so wait for "Work" text
    await driver!
        .waitFor(find.text('Work'), timeout: const Duration(seconds: 5));

    // Find and tap the skip previous icon.
    final previousIcon = find.byTooltip('Skip Previous');
    await driver!.tap(previousIcon);

    // Tap the skip previous icon again.
    await driver!.tap(previousIcon);

    // Back on Get ready
    await driver!
        .waitFor(find.text('Get ready'), timeout: const Duration(seconds: 5));
  });
}
