import 'dart:core';

import 'package:background_hiit_timer/models/interval_type.dart';
import 'package:background_hiit_timer/utils/constants.dart';

class TimerState {
  bool paused = false;
  String status = "";
  int currentInterval = 0;
  int currentMicroSeconds = 0;
  int intervalMicroSeconds = 0;
  double volume = 80;
  bool changeVolume = false;

  TimerState(
      this.paused,
      this.status,
      this.currentInterval,
      this.currentMicroSeconds,
      this.intervalMicroSeconds,
      this.volume,
      this.changeVolume);

  TimerState.empty() {
    paused = false;
    status = "Get ready";
    currentInterval = 0;
    currentMicroSeconds = 0;
    intervalMicroSeconds = 0;
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
