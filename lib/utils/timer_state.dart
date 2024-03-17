import 'dart:core';

class TimerState {
  /// Whether or not the timer is currently paused.
  ///
  /// e.g., false
  ///
  late bool paused;

  late String status;

  /// The number of exercises.
  ///
  /// e.g., "I need to do X but do it in Y way"
  ///
  late int numberOfWorkIntervalsRemaining;

  /// Current interval number, includes all possible
  /// interval status types. E.g. start, work, or rest.
  ///
  late int currentOverallInterval;

  late int currentMicroSeconds;

  late int iterations;

  TimerState(
      this.paused,
      this.numberOfWorkIntervalsRemaining,
      this.currentOverallInterval,
      this.currentMicroSeconds,
      this.status,
      this.iterations);

  TimerState.empty() {
    paused = false;
    numberOfWorkIntervalsRemaining = 0;
    currentOverallInterval = 0;
    currentMicroSeconds = 0;
    status = "start";
    iterations = 1;
  }
}
