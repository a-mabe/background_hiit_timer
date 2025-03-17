import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:background_hiit_timer/background_timer_controller.dart';
import 'package:background_hiit_timer/models/interval_type.dart';
import 'package:background_hiit_timer/utils/database.dart';
import 'package:background_hiit_timer/utils/log.dart';
import 'package:background_hiit_timer/models/timer_state.dart';
import 'package:background_hiit_timer/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'utils/constants.dart';

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

@pragma('vm:entry-point')
class CountdownState extends State<Countdown> with WidgetsBindingObserver {
  bool isActive = false;
  late SharedPreferences _preferences;

  static AudioPlayer? _player;

  // static AudioPlayer get player {
  //   _player ??= AudioPlayer();
  //   _player?.setAudioContext(AudioContext(
  //     android: AudioContextAndroid(
  //       contentType: AndroidContentType.sonification,
  //       audioFocus: AndroidAudioFocus.none,
  //       usageType: AndroidUsageType.media,
  //     ),
  //     iOS: AudioContextIOS(
  //       category: AVAudioSessionCategory.playback,
  //       options: {
  //         AVAudioSessionOptions.mixWithOthers,
  //       },
  //     ),
  //   ));
  //   return _player!;
  // }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // _initializeAudioContext();
    _initializeController();
    _initializePreferences();

    if (widget.controller?.autoStart ?? true) {
      _startTimer();
    }
  }

  // Future<void> _initializeAudioContext() async {
  //   AudioPlayer.global.setAudioContext(AudioContext(
  //     android: AudioContextAndroid(
  //       contentType: AndroidContentType.sonification,
  //       audioFocus: AndroidAudioFocus.none,
  //       usageType: AndroidUsageType.media,
  //     ),
  //     iOS: AudioContextIOS(
  //       category: AVAudioSessionCategory.playback,
  //       options: {
  //         AVAudioSessionOptions.mixWithOthers,
  //       },
  //     ),
  //   ));
  //   // await player.setAudioContext(AudioContext(
  //   //   android: AudioContextAndroid(
  //   //     contentType: AndroidContentType.sonification,
  //   //     audioFocus: AndroidAudioFocus.none,
  //   //     usageType: AndroidUsageType.media,
  //   //   ),
  //   //   iOS: AudioContextIOS(
  //   //     category: AVAudioSessionCategory.playback,
  //   //     options: {
  //   //       AVAudioSessionOptions.mixWithOthers,
  //   //     },
  //   //   ),
  //   // ));
  //   player.audioCache =
  //       AudioCache(prefix: 'packages/background_hiit_timer/assets/');
  // }

  Future<void> _initializePreferences() async {
    _preferences = await SharedPreferences.getInstance();
  }

  void _initializeController() {
    widget.controller?.setOnStart(_startTimer);
    widget.controller?.setOnStop(_stopTimer);
    widget.controller?.setOnPause(_onTimerPaused);
    widget.controller?.setOnResume(_onTimerResumed);
    widget.controller?.setOnRestart(_onTimerRestart);
    widget.controller?.setOnSkipNext(_onTimerSkipNext);
    widget.controller?.setOnSkipPrevious(_onTimerSkipPrevious);
    widget.controller?.isCompleted = false;
  }

  static Future<void> disposePlayer() async {
    if (_player != null) {
      await _player!.stop();
      await _player!.dispose();
      _player = null;
    }
  }

  @override
  void dispose() {
    print("Stopping service");
    disposePlayer();
    FlutterBackgroundService().invoke("stopService");
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onTimerPaused() async {
    logger.d("Pausing timer");
    if (isActive) {
      await _preferences.setBool("pause", true);
    }
  }

  void _onTimerResumed() async {
    logger.d("Resuming timer");
    if (isActive) {
      await _preferences.setBool("pause", false);
    }
  }

  void _onTimerRestart() {
    logger.d("Restarting timer");
    FlutterBackgroundService().invoke("restartService");
  }

  void _onTimerSkipNext() {
    logger.d("Skipping to next interval");
    FlutterBackgroundService().invoke("skipNext");
  }

  void _onTimerSkipPrevious() {
    logger.d("Skipping to previous interval");
    FlutterBackgroundService().invoke("skipPrevious");
  }

  void _startTimer() async {
    logger.d("Starting timer");
    setState(() => isActive = true);

    // Ensure the 'pause' shared preference is set to false when the timer starts
    SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setBool("pause", false);

    await _initializeService();
    widget.controller?.isCompleted = false;
  }

  void _stopTimer() {
    logger.d("Stopping timer");
    setState(() => isActive = false);
    FlutterBackgroundService().invoke("stopService");
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: FlutterBackgroundService().on('update'),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        final TimerState timerState = TimerState.fromMap(data);

        return widget.build(context, timerState);
      },
    );
  }

  Future<void> _initializeService() async {
    // await Future.delayed(Duration(seconds: 10));

    final service = FlutterBackgroundService();

    // Database setup
    DatabaseManager dbManager = DatabaseManager();
    await dbManager.clearDatabaseIfNotEmpty();
    await dbManager.openIntervalDatabase();
    await dbManager.insertIntervals(widget.intervals);

    // Initialize notification channels for Android/iOS
    await _setupNotifications();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: true,
          autoStartOnBoot: false,
          isForegroundMode: true,
          notificationChannelId: 'timer_foreground',
          initialNotificationTitle: 'TIMER',
          initialNotificationContent: 'Initializing',
          foregroundServiceNotificationId: 888,
          foregroundServiceTypes: [AndroidForegroundType.mediaPlayback]),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    service.startService();
  }

  Future<void> _setupNotifications() async {
    const channel = AndroidNotificationChannel(
      'timer_foreground',
      'TIMER',
      description: 'This channel is used for important notifications.',
      importance: Importance.low,
    );

    final notificationsPlugin = FlutterLocalNotificationsPlugin();

    if (Platform.isIOS || Platform.isAndroid) {
      await notificationsPlugin.initialize(
        const InitializationSettings(
          iOS: DarwinInitializationSettings(),
          android: AndroidInitializationSettings('ic_bg_service_small'),
        ),
      );
    }

    await notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    SharedPreferences preferences = await SharedPreferences.getInstance();
    double volume = preferences.getDouble("volume") ?? 80.0;
    bool changeVolume = preferences.getBool("changeVolume") ?? false;

    DatabaseManager dbManager = DatabaseManager();
    List<IntervalType> intervals = await dbManager.getIntervals();

    IntervalType currentInterval = intervals[0];
    TimerState timerState = TimerState(
        false,
        currentInterval.name,
        0,
        currentInterval.time * secondsFactor,
        currentInterval.time * secondsFactor,
        volume,
        changeVolume);

    _registerServiceEvents(service, intervals, preferences, timerState);
  }

  static Future<void> _registerServiceEvents(
    ServiceInstance service,
    List<IntervalType> intervals,
    SharedPreferences preferences,
    TimerState timerState,
  ) async {
    _player = AudioPlayer();

    await _player?.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
            .build());

    _player?.audioCache =
        AudioCache(prefix: 'packages/background_hiit_timer/assets/');

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('restartService').listen((_) {
      timerState.reset(intervals);
    });

    service.on('skipNext').listen((_) {
      timerState.advanceToNextInterval(intervals);
    });

    service.on('skipPrevious').listen((_) {
      if (timerState.currentInterval > 0) {
        timerState.currentInterval--;
        timerState.currentMicroSeconds =
            intervals[timerState.currentInterval].time * secondsFactor;
        timerState.intervalMicroSeconds =
            intervals[timerState.currentInterval].time * secondsFactor;
        timerState.status = intervals[timerState.currentInterval].name;
      }
    });

    service.on('stopService').listen((_) {
      service.stopSelf();
      disposePlayer();
    });

    Timer.periodic(interval, (timer) async {
      print("Timer is running");

      preferences.reload();
      timerState.paused = preferences.getBool('pause') ?? false;

      if (timerState.currentMicroSeconds <= 0) {
        timerState.status = "End";
      } else if (!timerState.paused && timerState.currentMicroSeconds > 0) {
        timerState.currentMicroSeconds -= interval.inMicroseconds;

        int intervalIndex = timerState.currentInterval;
        int nextIntervalIndex = intervalIndex + 1;

        if ([1500000, 2500000, 3500000]
            .contains(timerState.currentMicroSeconds)) {
          playSound(
              intervals[intervalIndex].countdownSound, _player!, preferences);
        } else if (timerState.currentMicroSeconds ==
            timerState.intervalMicroSeconds ~/ 2) {
          playSound(
              intervals[intervalIndex].halfwaySound, _player!, preferences);
        } else if (timerState.currentMicroSeconds == 700000) {
          if (intervalIndex < intervals.length - 1) {
            String sound = intervals[nextIntervalIndex].startSound;
            if (sound != "" && sound != "none") {
              playSound(sound, _player!, preferences);
            } else if (intervals[intervalIndex].endSound != "" &&
                intervals[intervalIndex].endSound != "none") {
              playSound(
                  intervals[intervalIndex].endSound, _player!, preferences);
            }
          } else {
            playSound(intervals[intervalIndex].endSound, _player!, preferences);
          }
        } else if (timerState.currentMicroSeconds == 0 &&
            intervalIndex < intervals.length - 1) {
          logger.d("Advancing to next interval");
          timerState.advanceToNextInterval(intervals);
        } else if (Platform.isIOS &&
            timerState.currentMicroSeconds % 1000000 == 0 &&
            timerState.currentMicroSeconds > 700000) {
          playSound(blankSoundFile, _player!, preferences);
        }
      }

      service.invoke('update', timerState.toMap());
    });
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }
}
