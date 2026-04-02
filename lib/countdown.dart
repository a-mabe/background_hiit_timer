import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:background_hiit_timer/countdown_controller.dart';
import 'package:background_hiit_timer/hiit_audio_handler.dart';
import 'package:background_hiit_timer/models/interval_type.dart';
import 'package:background_hiit_timer/models/timer_state.dart';
import 'package:background_hiit_timer/utils/log.dart';
import 'package:flutter/material.dart';

class Countdown extends StatefulWidget {
  final List<IntervalType> intervals;
  final Widget Function(BuildContext, TimerState) build;
  final Function? onFinished;
  final CountdownController? controller;

  const Countdown({
    super.key,
    required this.intervals,
    required this.build,
    this.onFinished,
    this.controller,
  });

  @override
  CountdownState createState() => CountdownState();
}

class CountdownState extends State<Countdown> {
  static HiitAudioHandler? _handler;

  static HiitAudioHandler? get handler => _handler;

  bool _isActive = false;

  @override
  void initState() {
    super.initState();
    _initController();
    if (widget.controller?.autoStart ?? true) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    if (_isActive) {
      _handler?.stopTimer();
    }
    super.dispose();
  }

  void _initController() {
    widget.controller?.setOnStart(_startTimer);
    widget.controller?.setOnStop(_stopTimer);
    widget.controller?.setOnPause(_pauseTimer);
    widget.controller?.setOnResume(_resumeTimer);
    widget.controller?.setOnRestart(_restartTimer);
    widget.controller?.setOnSkipNext(_skipNext);
    widget.controller?.setOnSkipPrevious(_skipPrevious);
    widget.controller?.isCompleted = false;
  }

  Future<void> _ensureHandler() async {
    if (_handler != null) return;

    logger.d('Initialising HiitAudioHandler via AudioService');

    _handler = await AudioService.init(
      builder: () => HiitAudioHandler(),
      config: AudioServiceConfig(
        androidNotificationChannelName: 'HIIT Timer',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        notificationColor: Color(0xFF000000),
        androidNotificationIcon: 'drawable/ic_bg_service_small',
      ),
    );
  }

  void _startTimer() async {
    logger.d('_startTimer');
    await _ensureHandler();

    const double defaultVolume = 80.0;

    await _handler!.startTimer(widget.intervals, defaultVolume);
    setState(() => _isActive = true);
    widget.controller?.isCompleted = false;
  }

  void _stopTimer() {
    logger.d('_stopTimer');
    _handler?.stopTimer();
    setState(() => _isActive = false);
  }

  void _pauseTimer() {
    logger.d('_pauseTimer');
    _handler?.pause();
  }

  void _resumeTimer() {
    logger.d('_resumeTimer');
    _handler?.play();
  }

  void _restartTimer() {
    logger.d('_restartTimer');
    _handler?.customAction(kActionRestart);
  }

  void _skipNext() {
    logger.d('_skipNext');
    _handler?.skipToNext();
  }

  void _skipPrevious() {
    logger.d('_skipPrevious');
    _handler?.skipToPrevious();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TimerState>(
        stream: _handler?.timerStateStream ?? const Stream.empty(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !_isActive) {
            return const Center(child: CircularProgressIndicator());
          }

          final timerState = snapshot.data!;

          if (timerState.status == "End" &&
              widget.controller?.isCompleted == false) {
            widget.controller?.isCompleted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.onFinished?.call();
            });
          }

          return widget.build(context, timerState);
        });
  }
}
