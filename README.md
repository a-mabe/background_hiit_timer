# background_hiit_timer

A Flutter package for creating a high-intensity interval training (HIIT) timer with full background service capabilities.

## Installation

Add `background_hiit_timer` to your `pubspec.yaml` file:

```yaml
dependencies:
  flutter:
    sdk: flutter
  background_hiit_timer: ^1.0.0
```

## Usage

Import `background_hiit_timer` in your Dart file:

```dart
import 'package:background_hiit_timer/background_hiit_timer.dart';
```

Create a `Countdown` widget and configure it with your interval settings:

```dart
Countdown(
  controller: _controller,
  seconds: 30,
  intervals: intervals,
  onFinished: () {},
  build: (_, TimerState timerState) {
    Text(timerState.currentMicroSeconds.toString())
  }
)
```

Ensure that your app is properly configured to handle background execution on both Android and iOS platforms. Refer to [flutter_background_service](https://pub.dev/packages/flutter_background_service) for additional details.

## Example

Check out the `example` directory in this repository for a complete example of how to use `background_hiit_timer` in a Flutter app.

## Credits

This package is inspired by the [`timer_count_down`](https://pub.dev/packages/timer_count_down) package by [Dizoft Team](https://github.com/DizoftTeam).

## License

MIT License. See [LICENSE](LICENSE) for details.