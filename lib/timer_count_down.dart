import 'dart:async';
import 'dart:developer';
import 'package:flutter/widgets.dart';
import 'package:timer_count_down/timer_controller.dart';
import 'package:audioplayers/audioplayers.dart';

///
/// Simple countdown timer.
///
class Countdown extends StatefulWidget {
  /// Length of the timer
  final int seconds;

  /// Build method for the timer
  final Widget Function(BuildContext, int) build;

  /// Called when finished
  final Function? onFinished;

  /// Build interval
  final Duration interval;

  /// Controller
  final CountdownController? controller;

  final String endSound;

  final String halfwaySound;

  final String countdownSound;

  final bool halfwayMark;

  ///
  /// Simple countdown timer
  ///
  Countdown({
    Key? key,
    required this.seconds,
    required this.build,
    this.endSound = 'short-rest-beep',
    this.halfwaySound = 'short-halfway-beep',
    this.countdownSound = 'countdown-beep',
    this.halfwayMark = false,
    this.interval = const Duration(seconds: 1),
    this.onFinished,
    this.controller,
  }) : super(key: key);

  @override
  _CountdownState createState() => _CountdownState();
}

///
/// State of timer
///
class _CountdownState extends State<Countdown> {
  // Multiplier of secconds
  final int _secondsFactor = 1000000;

  // Timer
  Timer? _timer;

  /// Internal control to indicate if the onFinished method was executed
  bool _onFinishedExecuted = false;

  // Current seconds
  late int _currentMicroSeconds;

  final player = AudioPlayer();

  @override
  void initState() {
    _currentMicroSeconds = widget.seconds * _secondsFactor;

    widget.controller?.setOnStart(_startTimer);
    widget.controller?.setOnPause(_onTimerPaused);
    widget.controller?.setOnResume(_onTimerResumed);
    widget.controller?.setOnRestart(_onTimerRestart);
    widget.controller?.isCompleted = false;

    if (widget.controller == null || widget.controller!.autoStart == true) {
      _startTimer();
    }

    super.initState();
  }

  @override
  void didUpdateWidget(Countdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seconds != widget.seconds)
      _currentMicroSeconds = widget.seconds * _secondsFactor;
  }

  @override
  void dispose() {
    if (_timer?.isActive == true) {
      _timer?.cancel();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.build(
      context,
      (_currentMicroSeconds / _secondsFactor).round(),
    );
  }

  ///
  /// Then timer paused
  ///
  void _onTimerPaused() {
    if (_timer?.isActive == true) {
      _timer?.cancel();
    }
  }

  ///
  /// Then timer resumed
  ///
  void _onTimerResumed() {
    _startTimer();
  }

  ///
  /// Then timer restarted
  ///
  void _onTimerRestart() {
    widget.controller?.isCompleted = false;
    _onFinishedExecuted = false;

    if (mounted) {
      setState(() {
        _currentMicroSeconds = widget.seconds * _secondsFactor;
      });

      _startTimer();
    }
  }

  ///
  /// Start timer
  ///
  void _startTimer() {
    if (_timer?.isActive == true) {
      _timer!.cancel();

      widget.controller?.isCompleted = true;
    }

    if (_currentMicroSeconds != 0) {
      _timer = Timer.periodic(
        widget.interval,
        (Timer timer) async {
          if (_currentMicroSeconds <= 0) {
            timer.cancel();

            if (widget.onFinished != null) {
              widget.onFinished!();
              this._onFinishedExecuted = true;
            }
            widget.controller?.isCompleted = true;
          } else {
            this._onFinishedExecuted = false;

            // print(widget.interval.inMicroseconds);
            // print(_currentMicroSeconds - widget.interval.inMicroseconds);
            // print((widget.seconds * _secondsFactor) / 2);
            // print(((widget.seconds * _secondsFactor) / 2) + 500000);
            // print("---");

            // Halfway
            if (widget.halfwayMark &&
                (_currentMicroSeconds - widget.interval.inMicroseconds) ==
                    ((widget.seconds * _secondsFactor) / 2) + 500000 &&
                widget.halfwaySound != 'none') {
              await player
                  .play(AssetSource('audio/${widget.halfwaySound}.mp3'));
            }
            // 3, 2, 1
            else if ((_currentMicroSeconds - widget.interval.inMicroseconds) ==
                    3500000 ||
                (_currentMicroSeconds - widget.interval.inMicroseconds) ==
                    2500000 ||
                (_currentMicroSeconds - widget.interval.inMicroseconds) ==
                    1500000) {
              if (widget.countdownSound != 'none') {
                await player
                    .play(AssetSource('audio/${widget.countdownSound}.mp3'));
              }
            }
            // End
            else if (_currentMicroSeconds - widget.interval.inMicroseconds ==
                    500000 &&
                widget.endSound != 'none') {
              await player.play(AssetSource('audio/${widget.endSound}.mp3'));
            }

            setState(() {
              _currentMicroSeconds =
                  _currentMicroSeconds - widget.interval.inMicroseconds;
            });
          }
        },
      );
    } else if (!this._onFinishedExecuted) {
      if (widget.onFinished != null) {
        widget.onFinished!();
        this._onFinishedExecuted = true;
      }
      widget.controller?.isCompleted = true;
    }
  }
}
