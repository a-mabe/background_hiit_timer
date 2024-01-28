import 'dart:core';

class TimerConfig {
  /// Amount of time for an exercise, in seconds.
  ///
  /// e.g., 30
  ///
  late int exerciseTime;

  /// Amount of time between exercises, in seconds.
  ///
  /// e.g., 30
  ///
  late int restTime;

  /// Amount of time between iterations, in seconds.
  ///
  /// e.g., 30
  ///
  late int breakTime;

  late int warmupTime;

  late int cooldownTime;

  late int firstIteration;

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
      this.exerciseTime,
      this.restTime,
      this.breakTime,
      this.warmupTime,
      this.cooldownTime,
      this.firstIteration,
      this.workSound,
      this.restSound,
      this.halfwaySound,
      this.completeSound,
      this.countdownSound);

  TimerConfig.empty() {
    exerciseTime = 0;
    restTime = 0;
    breakTime = 0;
    warmupTime = 0;
    cooldownTime = 0;
    firstIteration = 0;
    workSound = "short-whistle";
    restSound = "short-rest-beep";
    halfwaySound = "short-halfway-beep";
    countdownSound = "countdown-beep";
    completeSound = "long-bell";
  }
}
