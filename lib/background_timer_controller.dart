import 'package:flutter/widgets.dart';

///
/// Controller for CountDownTimer
///
class CountdownController {
  /// Called when pausing the timer.
  VoidCallback? onPause;

  /// Called when resuming the timer.
  VoidCallback? onResume;

  /// Called when restarting the timer.
  VoidCallback? onRestart;

  /// Called when the timer starts.
  VoidCallback? onStart;

  /// Called when the timer stops.
  VoidCallback? onStop;

  /// Called when skipping to the next interval.
  VoidCallback? onSkipNext;

  /// Called when skipping to the previous interval.
  VoidCallback? onSkipPrevious;

  ///
  /// Checks if the timer is running and enables you to take actions
  /// according to that. if the timer is still active,
  ///
  /// `isCompleted` returns `false` and vice versa.
  ///
  /// for example:
  ///
  /// ``` dart
  ///   _controller.isCompleted ? _controller.restart() : _controller.pause();
  /// ```
  ///
  bool? isCompleted;

  /// Whether or not the timer should automatically begin.
  final bool autoStart;

  /// Constructor
  CountdownController({this.autoStart = false});

  /// Run timer
  void start() {
    if (onStart != null) {
      onStart!();
    }
  }

  /// Set onStart callback.
  void setOnStart(VoidCallback onStart) {
    this.onStart = onStart;
  }

  /// Stop timer
  void stop() {
    if (onStop != null) {
      onStop!();
    }
  }

  /// Set onStop callback.
  void setOnStop(VoidCallback onStop) {
    this.onStop = onStop;
  }

  /// Set timer pause.
  Future<void> pause() async {
    if (onPause != null) {
      onPause!();
    }
  }

  /// Set onPause callback.
  void setOnPause(VoidCallback onPause) {
    this.onPause = onPause;
  }

  /// Resume from pause.
  void resume() {
    if (onResume != null) {
      onResume!();
    }
  }

  /// Set onResume callback.
  void setOnResume(VoidCallback onResume) {
    this.onResume = onResume;
  }

  /// Restart timer, starts things fresh.
  void restart() {
    if (onRestart != null) {
      onRestart!();
    }
  }

  /// set onRestart callback.
  void setOnRestart(VoidCallback onRestart) {
    this.onRestart = onRestart;
  }

  /// Skip to the next interval.
  void skipNext() {
    if (onSkipNext != null) {
      onSkipNext!();
    }
  }

  /// Set onSkipNext callback.
  void setOnSkipNext(VoidCallback onSkipNext) {
    this.onSkipNext = onSkipNext;
  }

  /// Skip to the previous interval.
  void skipPrevious() {
    if (onSkipPrevious != null) {
      onSkipPrevious!();
    }
  }

  /// Set onSkipPrevious callback.
  void setOnSkipPrevious(VoidCallback onSkipPrevious) {
    this.onSkipPrevious = onSkipPrevious;
  }
}
