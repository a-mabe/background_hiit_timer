import 'package:background_hiit_timer/models/interval_type.dart';
import 'package:background_hiit_timer/utils/constants.dart';

class TimerState {
  bool paused;
  String status;
  int currentInterval;
  int currentMicroSeconds;
  int intervalMicroSeconds;
  double volume;
  bool changeVolume;

  TimerState(
    this.paused,
    this.status,
    this.currentInterval,
    this.currentMicroSeconds,
    this.intervalMicroSeconds,
    this.volume,
    this.changeVolume,
  );

  TimerState.empty()
      : paused = false,
        status = "Get ready",
        currentInterval = 0,
        currentMicroSeconds = 0,
        intervalMicroSeconds = 0,
        volume = 80,
        changeVolume = false;

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
      status = "End";
    }
  }
}
