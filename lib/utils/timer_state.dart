import 'dart:core';

import 'package:background_hiit_timer/models/interval_type.dart';
import 'package:background_hiit_timer/utils/constants.dart';

class TimerState {
  bool paused = false;
  String status = "";
  int currentInterval = 0;
  int currentMicroSeconds = 0;
  int intervalMicroSeconds = 0;
  int iteration = 0;
  double volume = 80;
  bool changeVolume = false;

  TimerState(
      this.paused,
      this.status,
      this.currentInterval,
      this.currentMicroSeconds,
      this.intervalMicroSeconds,
      this.iteration,
      this.volume,
      this.changeVolume);

  TimerState.empty() {
    paused = false;
    status = "Get ready";
    currentInterval = 0;
    currentMicroSeconds = 0;
    intervalMicroSeconds = 0;
    iteration = 1;
    volume = 80;
    changeVolume = false;
  }

  Map<String, dynamic> toMap() {
    return {
      'paused': paused,
      'status': status,
      'currentInterval': currentInterval,
      'currentMicroSeconds': currentMicroSeconds,
      'intervalMicroSeconds': intervalMicroSeconds,
      'iteration': iteration,
      'volume': volume,
      'changeVolume': changeVolume,
    };
  }

  factory TimerState.fromMap(Map<String, dynamic> map) {
    double volume = map['volume'].toDouble() ?? 80.0;

    return TimerState(
      map['paused'] ?? false,
      map['status'] ?? "",
      map['currentInterval'] ?? 0,
      map['currentMicroSeconds'] ?? 0,
      map['intervalMicroSeconds'] ?? 0,
      map['iteration'] ?? 1,
      volume,
      map['changeVolume'] ?? false,
    );
  }

  void reset(List<IntervalType> intervals) {
    paused = false;
    status = intervals[0].name;
    currentInterval = 0;
    currentMicroSeconds = intervals[0].time * secondsFactor;
    intervalMicroSeconds = intervals[0].time * secondsFactor;
    iteration = 1;
    changeVolume = false;
  }

  void advanceToNextInterval(List<IntervalType> intervals) {
    if (currentInterval < intervals.length - 1) {
      currentInterval++;
      currentMicroSeconds = intervals[currentInterval].time * secondsFactor;
      intervalMicroSeconds = intervals[currentInterval].time * secondsFactor;
      status = intervals[currentInterval].name;
    } else {
      currentMicroSeconds = 0;
    }
  }
}


// import 'dart:core';

// class TimerState {
//   /// Whether or not the timer is currently paused.
//   ///
//   /// e.g., false
//   ///
//   late bool paused;

//   late String status;

//   /// The number of exercises.
//   ///
//   /// e.g., "I need to do X but do it in Y way"
//   ///
//   late int numberOfWorkIntervalsRemaining;

//   /// Current interval number, includes all possible
//   /// interval status types. E.g. start, work, or rest.
//   ///
//   late int currentOverallInterval;

//   late int currentMicroSeconds;

//   late int iterations;

//   TimerState(
//       this.paused,
//       this.numberOfWorkIntervalsRemaining,
//       this.currentOverallInterval,
//       this.currentMicroSeconds,
//       this.status,
//       this.iterations);

//   TimerState.empty() {
//     paused = false;
//     numberOfWorkIntervalsRemaining = 0;
//     currentOverallInterval = 0;
//     currentMicroSeconds = 0;
//     status = "start";
//     iterations = 1;
//   }
// }
