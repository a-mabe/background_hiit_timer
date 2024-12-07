import 'dart:async';
import 'dart:io';
import 'dart:ui';
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
import 'package:soundpool/soundpool.dart';

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

class CountdownState extends State<Countdown> with WidgetsBindingObserver {
  bool isActive = false;
  late SharedPreferences _preferences;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _initializeController();
    _initializePreferences();

    if (widget.controller?.autoStart ?? true) {
      _startTimer();
    }
  }

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

  @override
  void dispose() {
    if (isActive) {
      FlutterBackgroundService().invoke("stopService");
    }
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

    Soundpool pool = Soundpool.fromOptions();
    DatabaseManager dbManager = DatabaseManager();
    List<IntervalType> intervals = await dbManager.getIntervals();

    Map<String, int> soundMap = await _loadIntervalSounds(intervals, pool);
    IntervalType currentInterval = intervals[0];
    TimerState timerState = TimerState(
        false,
        currentInterval.name,
        0,
        currentInterval.time * secondsFactor,
        currentInterval.time * secondsFactor,
        volume,
        changeVolume);

    _registerServiceEvents(
        service, intervals, preferences, soundMap, timerState, pool);
  }

  static Future<Map<String, int>> _loadIntervalSounds(
      List<IntervalType> intervals, Soundpool pool) async {
    Map<String, int> soundMap = {};
    Map<String, int> loadedSounds = {};

    for (int i = 0; i < intervals.length; i++) {
      if (intervals[i].startSound.isNotEmpty) {
        if (!loadedSounds.containsKey(intervals[i].startSound)) {
          int soundID = await loadSound(intervals[i].startSound, pool);
          loadedSounds[intervals[i].startSound] = soundID;
        }
        soundMap['${i}_sound'] = loadedSounds[intervals[i].startSound]!;
      } else {
        soundMap['${i}_sound'] = -1;
      }

      if (intervals[i].halfwaySound.isNotEmpty) {
        if (!loadedSounds.containsKey(intervals[i].halfwaySound)) {
          int halfwaySoundID = await loadSound(intervals[i].halfwaySound, pool);
          loadedSounds[intervals[i].halfwaySound] = halfwaySoundID;
        }
        soundMap['${i}_halfwaySound'] =
            loadedSounds[intervals[i].halfwaySound]!;
      } else {
        soundMap['${i}_halfwaySound'] = -1;
      }

      if (intervals[i].countdownSound.isNotEmpty) {
        if (!loadedSounds.containsKey(intervals[i].countdownSound)) {
          int countdownSoundID =
              await loadSound(intervals[i].countdownSound, pool);
          loadedSounds[intervals[i].countdownSound] = countdownSoundID;
        }
        soundMap['${i}_countdownSound'] =
            loadedSounds[intervals[i].countdownSound]!;
      } else {
        soundMap['${i}_countdownSound'] = -1;
      }

      if (intervals[i].endSound.isNotEmpty) {
        if (!loadedSounds.containsKey(intervals[i].endSound)) {
          int endSoundID = await loadSound(intervals[i].endSound, pool);
          loadedSounds[intervals[i].endSound] = endSoundID;
        }
        soundMap['${i}_endSound'] = loadedSounds[intervals[i].endSound]!;
      } else {
        soundMap['${i}_endSound'] = -1;
      }
    }
    return soundMap;
  }

  static Future<void> _registerServiceEvents(
      ServiceInstance service,
      List<IntervalType> intervals,
      SharedPreferences preferences,
      Map<String, int> soundMap,
      TimerState timerState,
      Soundpool pool) async {
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
    });

    int blankSoundId = await loadSound('blank', pool);

    Timer.periodic(interval, (timer) async {
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
          await playSound(
              soundMap["${intervalIndex}_countdownSound"]!, pool, preferences);
        } else if (timerState.currentMicroSeconds ==
            timerState.intervalMicroSeconds ~/ 2) {
          await playSound(
              soundMap["${intervalIndex}_halfwaySound"]!, pool, preferences);
        } else if (timerState.currentMicroSeconds == 700000) {
          if (intervalIndex < intervals.length - 1) {
            int soundId = soundMap["${nextIntervalIndex}_sound"]!;
            if (soundId != 0) {
              await playSound(soundId, pool, preferences);
            } else if (soundMap["${intervalIndex}_endSound"]! != 0) {
              await playSound(
                  soundMap["${intervalIndex}_endSound"]!, pool, preferences);
            }
          } else {
            await playSound(
                soundMap["${intervalIndex}_endSound"]!, pool, preferences);
          }
        } else if (timerState.currentMicroSeconds == 0 &&
            intervalIndex < intervals.length - 1) {
          logger.d("Advancing to next interval");
          timerState.advanceToNextInterval(intervals);
        }
      } else if (timerState.currentMicroSeconds % 1000000 == 0) {
        await playSound(blankSoundId, pool, preferences);
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
