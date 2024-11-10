# background_hiit_timer

A Flutter package for creating a high-intensity interval training (HIIT) timer with background service capabilities.

## Installation

Add `background_hiit_timer` to your `pubspec.yaml` file:

```yaml
dependencies:
  flutter:
    sdk: flutter
  background_hiit_timer: ^1.0.0
```

## Basic Usage

Import `background_hiit_timer` in your Dart file:

```dart
import 'package:background_hiit_timer/background_hiit_timer.dart';
```

1. Ensure that your app is properly configured to handle background execution on both Android and iOS platforms. Refer to [flutter_background_service](https://pub.dev/packages/flutter_background_service) for details.

2. Define a set of intervals:

```
final List<IntervalType> intervals = [
    IntervalType(
        id: "0",
        workoutId: "1",
        time: 10,
        name: "Get ready",
        color: 0,
        intervalIndex: 0,
        startSound: "",
        halfwaySound: "",
        countdownSound: "countdown-beep",
        endSound: ""),
    IntervalType(
        id: "1",
        workoutId: "1",
        time: 10,
        name: "Warmup",
        color: 0,
        intervalIndex: 1,
        startSound: "long-bell",
        halfwaySound: "",
        countdownSound: "countdown-beep",
        endSound: ""),
    IntervalType(
        id: "2",
        workoutId: "1",
        time: 20,
        name: "Work",
        color: 0,
        intervalIndex: 2,
        startSound: "long-bell",
        halfwaySound: "short-halfway-beep",
        countdownSound: "countdown-beep",
        endSound: ""),
    IntervalType(
        id: "3",
        workoutId: "1",
        time: 10,
        name: "Rest",
        color: 0,
        intervalIndex: 3,
        startSound: "long-rest-beep",
        halfwaySound: "",
        countdownSound: "countdown-beep",
        endSound: ""),
    IntervalType(
        id: "4",
        workoutId: "1",
        time: 10,
        name: "Cooldown",
        color: 0,
        intervalIndex: 4,
        startSound: "long-rest-beep",
        countdownSound: "countdown-beep",
        endSound: "horn",
        halfwaySound: ""),
  ];
```

3. Define a controller:

```
final CountdownController _controller = CountdownController(autoStart: true);
```

4. Create a `Countdown` widget and configure it with your interval settings:

```dart
Countdown(
  controller: _controller,
  intervals: intervals,
  onFinished: () {},
  build: (_, TimerState timerState) {
    Text(timerState.currentMicroSeconds.toString())
  }
)
```

## Example

Check out the [example](example) directory in this repository for a complete example of how to use `background_hiit_timer` in a Flutter app.

## Credits

This package is inspired by the [`timer_count_down`](https://pub.dev/packages/timer_count_down) package by [Dizoft Team](https://github.com/DizoftTeam).

## License

MIT License. See [LICENSE](LICENSE) for details.