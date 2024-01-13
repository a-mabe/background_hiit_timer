import 'dart:core';

class TimerConfig {
  /// Whether or not the timer is currently paused.
  ///
  /// e.g., false
  ///
  late bool paused;

  /// The number of exercises.
  ///
  /// e.g., "I need to do X but do it in Y way"
  ///
  late int numberOfWorkIntervals;

  /// Amount of time for an exercise, in seconds.
  ///
  /// e.g., 30
  ///
  late int exerciseTime;

  /// Amount of time between exercises, in seconds. (Rest time)
  ///
  /// e.g., 30
  ///
  late int restTime;

  /// Sound for the work/exercise period.
  ///
  /// e.g., "beep"
  ///
  late String workSound;

  /// Sound for the rest period.
  ///
  /// e.g., "ding"
  ///
  late String restSound;

  /// Sound for the halfway mark.
  ///
  /// e.g., "ding"
  ///
  late String halfwaySound;

  /// Sound for the end of the timer.
  ///
  /// e.g., "ding"
  ///
  late String completeSound;

  /// Sound to play at the 3, 2, and 1
  /// second mark of each interval.
  ///
  /// e.g., "beep"
  ///
  late String countdownSound;

  TimerConfig(
      this.paused,
      this.numberOfWorkIntervals,
      this.exerciseTime,
      this.restTime,
      this.workSound,
      this.restSound,
      this.halfwaySound,
      this.completeSound,
      this.countdownSound);

  TimerConfig.empty() {
    paused = false;
    numberOfWorkIntervals = 0;
    exerciseTime = 0;
    restTime = 0;
    workSound = "short-whistle";
    restSound = "short-rest-beep";
    halfwaySound = "short-halfway-beep";
    countdownSound = "countdown-beep";
    completeSound = "long-bell";
  }
}
