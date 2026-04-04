import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:background_hiit_timer/countdown_controller.dart';
import 'package:background_hiit_timer/hiit_audio_handler.dart';
import 'package:background_hiit_timer/models/interval_type.dart';
import 'package:background_hiit_timer/models/timer_state.dart';
import 'package:background_hiit_timer/utils/log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

  // ── Static handler shared across all Countdown instances ──────────────────

  static HiitAudioHandler? _handler;
  static HiitAudioHandler? get handler => _handler;

  /// Must be called in main() before runApp().
  ///
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await Countdown.initialize();
  ///   runApp(MyApp());
  /// }
  /// ```
  static Future<void> initialize({
    String notificationChannelName = 'HIIT Timer',
    String androidNotificationIcon = 'drawable/ic_bg_service_small',
    Color notificationColor = Colors.black,
    bool androidStopForegroundOnPause = true,
  }) async {
    if (_handler != null) return;

    // Request notification permission before initialising the handler
    if (Platform.isIOS) {
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: false, sound: false);
    }

    if (Platform.isAndroid) {
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    logger.d('Countdown.initialize — registering HiitAudioHandler');

    _handler = await AudioService.init(
      builder: () => HiitAudioHandler(),
      config: AudioServiceConfig(
        androidNotificationChannelId: 'hiit_timer',
        androidNotificationChannelName: notificationChannelName,
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: androidStopForegroundOnPause,
        notificationColor: notificationColor,
        androidNotificationIcon: androidNotificationIcon,
      ),
    );
  }

  @override
  CountdownState createState() => CountdownState();
}

class CountdownState extends State<Countdown> with WidgetsBindingObserver {
  bool _isActive = false;

  // Convenience getter so we're not typing Countdown._handler everywhere
  HiitAudioHandler? get _handler => Countdown._handler;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initController();
    if (widget.controller?.autoStart ?? true) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_isActive) {
      _handler?.stopTimer();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _handler?.stopTimer();
    }
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

  void _startTimer() async {
    logger.d('_startTimer');

    if (_handler == null) {
      throw StateError(
        'Countdown.initialize() must be called in main() before using the timer.',
      );
    }

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
      },
    );
  }
}
