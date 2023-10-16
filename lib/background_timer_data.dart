import 'dart:core';

class BackgroundTimerData {
  ///
  /// -------------
  /// FIELDS
  /// -------------
  ///

  /// Current seconds
  int currentMicroSeconds = 0;

  /// Current timer status
  String status = "";

  /// Current interval work number
  int numberOfWorkIntervals = 0;

  /// Current interval number
  int numberOfIntervals = 0;

  /// Whether the timer is paused
  bool paused = false;

  ///
  /// -------------
  /// END FIELDS
  /// -------------
  ///

  ///
  /// -------------
  /// CONSTRUCTORS
  /// -------------
  ///

  BackgroundTimerData(this.currentMicroSeconds, this.status,
      this.numberOfWorkIntervals, this.numberOfIntervals, this.paused);

  BackgroundTimerData.empty() {
    currentMicroSeconds = 0;
    status = "";
    numberOfWorkIntervals = 0;
    numberOfIntervals = 0;
    paused = false;
  }

  ///
  /// -------------
  /// END CONSTRUCTORS
  /// -------------
  ///
  ///
  /// -------------
  /// FUNCTIONS
  /// -------------
  ///

  ///
  /// -------------
  /// END FUNCTIONS
  /// -------------
  ///
}
