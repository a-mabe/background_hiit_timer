/// Defines the object returned from the background timer process
/// that is sent to the foreground.
///

import 'dart:core';

class BackgroundTimerData {
  /// Current microseconds, used to calculate how many
  /// seconds to display on the UI.
  ///
  int currentMicroSeconds = 0;

  /// Current timer interval status.
  ///
  /// One of: start, work, rest, end.
  ///
  String status = "";

  /// Remaining number of work intervals.
  ///
  int remainingWorkIntervals = 0;

  /// Current interval number, includes all possible
  /// interval status types. E.g. start, work, or rest.
  ///
  int currentOverallInterval = 0;

  /// Whether the timer is currently paused.
  ///
  bool paused = false;

  int iterations = 0;

  // double volume = 80.0;

  ///
  /// Constructor
  ///
  BackgroundTimerData(
      this.currentMicroSeconds,
      this.status,
      this.remainingWorkIntervals,
      this.currentOverallInterval,
      this.paused,
      this.iterations);

  ///
  /// Empty constructor
  ///
  BackgroundTimerData.empty() {
    currentMicroSeconds = 0;
    status = "";
    remainingWorkIntervals = 0;
    currentOverallInterval = 0;
    paused = false;
    iterations = 0;
  }
}
