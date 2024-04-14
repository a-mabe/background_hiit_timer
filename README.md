# background_hiit_timer

A Flutter package for creating a background HIIT (High-Intensity Interval Training) timer. This package is based on the [`timer_count_down`](https://pub.dev/packages/timer_count_down) package and extends its functionality to support background execution for interval timers.

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
    workSeconds: 20,
    restSeconds: 10,
    getreadySeconds: 10,
    breakSeconds: 30,
    warmupSeconds: 60,
    cooldownSeconds: 60,
    numberOfWorkIntervals: 8,
    iterations: 2,
    onFinished: () {},
    build: Text(timerData.currentMicroSeconds.toString())
```

Ensure that your app is properly configured to handle background execution on both Android and iOS platforms.

## Example

Check out the `example` directory in this repository for a complete example of how to use `background_hiit_timer` in a Flutter app.

## Credits

This package is based on the [`timer_count_down`](https://pub.dev/packages/timer_count_down) package by [Dizoft Team](https://github.com/DizoftTeam).

## License

MIT License. See [LICENSE](LICENSE) for details.