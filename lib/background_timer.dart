import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:background_timer/background_timer_controller.dart';
import 'package:background_timer/background_timer_data.dart';
import 'package:soundpool/soundpool.dart';

/// Possible interval states
enum IntervalStates { start, work, rest, complete }

///
/// Background service countdown interval timer.
///
class Countdown extends StatefulWidget {
  /// Length of the work interval
  final int workSeconds;

  /// Length of the rest interval
  final int restSeconds;

  /// Build method for the timer
  final Widget Function(BuildContext, BackgroundTimerData) build;

  /// Called when finished
  final Function? onFinished;

  /// Controller for the countdown timer.
  /// Allows external control and monitoring of the countdown timer.
  ///
  final CountdownController? controller;

  /// End sound - Sound to play at session completion.
  /// E.g. all intervals finished and timer complete.
  ///
  final String endSound;

  /// Work sound - Sound to play at the start of the
  /// work interval.
  ///
  final String workSound;

  /// Rest sound - Sound to play at the start of the
  /// rest interval.
  ///
  final String restSound;

  /// Halfway sound - Sound to play at the halfway point
  /// of the work interval.
  ///
  final String halfwaySound;

  /// Countdown sound - Sound to play at the 3, 2, and 1
  /// second mark of each interval. Signifies the current
  /// interval is nearing the end.
  ///
  final String countdownSound;

  /// Number of work intervals in the session.
  ///
  /// The number of rest intervals will be extrapolated from
  /// this value.
  ///
  final int numberOfWorkIntervals;

  /// Current interval status.
  ///
  /// One of: start, work, rest, end.
  ///
  final String status;

  /// Describes the previous view before navigating to
  /// the timer screen.
  ///
  final String navigatedFrom;

  ///
  /// Simple countdown timer
  ///
  const Countdown({
    Key? key,
    required this.workSeconds,
    required this.restSeconds,
    required this.numberOfWorkIntervals,
    required this.build,
    this.status = 'start',
    this.endSound = 'horn',
    this.workSound = 'short-whistle',
    this.restSound = 'short-rest-beep',
    this.halfwaySound = 'short-halfway-beep',
    this.countdownSound = 'countdown-beep',
    this.navigatedFrom = "",
    this.onFinished,
    this.controller,
  }) : super(key: key);

  @override
  CountdownState createState() => CountdownState();
}

///
/// State of timer
///
class CountdownState extends State<Countdown> with WidgetsBindingObserver {
  // Multiplier of secconds
  final int _secondsFactor = 1000000;

  /// Current seconds
  late int _currentMicroSeconds;

  /// Current timer status
  late String _status;

  /// Current work interval number
  late int _numberOfWorkIntervals;

  /// Current interval number
  late int _numberOfIntervals;

  /// Whether the timer is paused
  late bool _paused;

  /// Timer is currently active
  bool isActive = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _currentMicroSeconds = 10 * _secondsFactor;

    widget.controller?.setOnStart(_startTimer);
    widget.controller?.setOnPause(_onTimerPaused);
    widget.controller?.setOnResume(_onTimerResumed);
    widget.controller?.setOnRestart(_onTimerRestart);
    widget.controller?.isCompleted = false;

    if ((widget.controller == null && widget.navigatedFrom != "") ||
        (widget.controller!.autoStart == true && widget.navigatedFrom != "")) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(Countdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workSeconds != widget.workSeconds) {
      _currentMicroSeconds = widget.workSeconds * _secondsFactor;
    }
  }

  @override
  void dispose() {
    /// Stop timer if active
    if (isActive) {
      final service = FlutterBackgroundService();
      service.invoke("stopService");
    }

    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  ///
  /// Then timer paused
  ///
  void _onTimerPaused() async {
    /// Stop timer if currently active. Otherwise, a timer
    /// is not currently running so we ignore the timer pause.
    if (isActive) {
      SharedPreferences preferences = await SharedPreferences.getInstance();
      await preferences.setBool("pause", true);
    }
  }

  ///
  /// Then timer resumed
  ///
  void _onTimerResumed() async {
    /// Resume timer if currently active. Otherwise, a timer
    /// is not currently running so we ignore the timer resume.
    if (isActive) {
      SharedPreferences preferences = await SharedPreferences.getInstance();
      await preferences.setBool("pause", false);
    }
  }

  ///
  /// Then timer restarted
  ///
  void _onTimerRestart() {
    final service = FlutterBackgroundService();
    service.invoke("stopService");
    _startTimer();
  }

  ///
  /// Start timer
  ///
  void _startTimer() async {
    /// Set the timer to active
    isActive = true;

    SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setBool("pause", false);
    await preferences.setInt("workSeconds", widget.workSeconds);
    await preferences.setInt("restSeconds", widget.restSeconds);
    await preferences.setString("halfwaySound", widget.halfwaySound);
    await preferences.setString("endSound", widget.endSound);
    await preferences.setString("countdownSound", widget.countdownSound);
    await preferences.setString("workSound", widget.workSound);
    await preferences.setString("restSound", widget.restSound);
    await preferences.setInt(
        "numberOfWorkIntervals", widget.numberOfWorkIntervals);

    await initializeService().then((value) {
      widget.controller?.isCompleted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: FlutterBackgroundService().on('update'),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        final data = snapshot.data!;
        _currentMicroSeconds = data["microSeconds"];
        _status = data["status"];
        _numberOfWorkIntervals = data["numberOfWorkIntervals"];
        _numberOfIntervals = data["numberOfIntervals"];
        _paused = data["paused"];

        if (_currentMicroSeconds == 0 &&
            widget.controller?.isCompleted == false) {
          if (widget.onFinished != null) {
            widget.onFinished!();
          }
          widget.controller?.isCompleted = true;
        } else if (_currentMicroSeconds > 0) {
          widget.controller?.isCompleted = false;
        }

        /// Data sent back from the timer
        BackgroundTimerData backgroundTimerData = BackgroundTimerData(
            _currentMicroSeconds,
            _status,
            _numberOfWorkIntervals,
            _numberOfIntervals,
            _paused);

        return widget.build(context, backgroundTimerData);
      },
    );
  }

  ///
  /// Initialize background service
  ///
  Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    /// --- FOR BACKGROUND SERVICE NOTIFICATION CHANNEL ---

    /// OPTIONAL, using custom notification channel id
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'my_foreground', // id
      'MY FOREGROUND SERVICE', // title
      description:
          'This channel is used for important notifications.', // description
      importance: Importance.low, // importance must be at low or higher level
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    if (Platform.isIOS || Platform.isAndroid) {
      await flutterLocalNotificationsPlugin.initialize(
        const InitializationSettings(
          iOS: DarwinInitializationSettings(),
          android: AndroidInitializationSettings('ic_bg_service_small'),
        ),
      );
    }

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    /// --- END FOR BACKGROUND SERVICE NOTIFICATION CHANNEL ---

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        // This will be executed when app is in foreground
        // or background in separated isolate
        onStart: onStart,

        // auto start service
        autoStart: true,
        isForegroundMode: true,

        notificationChannelId: 'my_foreground',
        initialNotificationTitle: 'AWESOME SERVICE',
        initialNotificationContent: 'Initializing',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        // auto start service
        autoStart: true,

        // this will be executed when app is in foreground in separated isolate
        onForeground: onStart,

        // you have to enable background fetch capability on xcode project
        onBackground: onIosBackground,
      ),
    );

    service.startService();
  }

  ///
  /// Run on iOS background
  ///
  @pragma('vm:entry-point')
  Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    return true;
  }

  ///
  /// Run on service start
  ///
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    final session = await AudioSession.instance;
    // session.setActive(false);
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.mixWithOthers,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      avAudioSessionRouteSharingPolicy:
          AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.sonification,
        flags: AndroidAudioFlags.audibilityEnforced,
        usage: AndroidAudioUsage.notification,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ));

    SoundpoolOptions soundpoolOptions = const SoundpoolOptions();

    Soundpool pool = Soundpool.fromOptions(options: soundpoolOptions);

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    /// Timer interval is half a second
    Duration interval = const Duration(microseconds: 100000);

    /// Factor by microseconds
    const int secondsFactor = 1000000;

    /// --- Grab shared preferences ---
    SharedPreferences preferences = await SharedPreferences.getInstance();
    preferences.reload();
    bool? paused = false;
    final String? workSound = preferences.getString('workSound');
    final String? halfwaySound = preferences.getString('halfwaySound');
    final String? countdownSound = preferences.getString('countdownSound');
    final String? restSound = preferences.getString('restSound');
    final String? endSound = preferences.getString('endSound');
    final int? workSeconds = preferences.getInt("workSeconds");
    final int? restSeconds = preferences.getInt("restSeconds");
    int? numberOfWorkIntervals = preferences.getInt("numberOfWorkIntervals");
    int numberOfIntervals = 0;

    /// --- End grab shared preferences ---

    /// First interval status is start
    IntervalStates status = IntervalStates.start;

    int blankSoundID = await rootBundle
        .load("packages/background_timer/lib/assets/audio/blank.mp3")
        .then((ByteData soundData) {
      return pool.load(soundData);
    });

    int countdownSoundID = await loadSound(countdownSound!, pool);
    int halfwaySoundID = await loadSound(halfwaySound!, pool);
    int restSoundID = await loadSound(restSound!, pool);
    int workSoundID = await loadSound(workSound!, pool);
    int endSoundID = await loadSound(endSound!, pool);

    /// 10 seconds * microseconds factor
    int? currentMicroSeconds = 10 * secondsFactor;

    Timer.periodic(interval, (timer) async {
      preferences.reload();
      paused = preferences.getBool('pause');
      if (!paused!) {
        /// If the timer has not been completed, then
        /// deduct half a second from the timer
        if (status != IntervalStates.complete) {
          currentMicroSeconds =
              (currentMicroSeconds! - interval.inMicroseconds);
        }

        /// If there is no more time on the timer to deduct, then
        /// calculate the next action.
        if (currentMicroSeconds! < -500000) {
          /// Determine timer status

          /// If the status was start
          if (status == IntervalStates.start) {
            /// Switch to the work state
            status = IntervalStates.work;

            /// Update the current time to the work time
            currentMicroSeconds = workSeconds! * secondsFactor;

            /// Since we have changed intervals, decrement the
            /// number of intervals at each work session
            numberOfWorkIntervals = numberOfWorkIntervals! - 1;
          }

          /// If the status was work
          else if (status == IntervalStates.work) {
            /// Switch to the rest state
            status = IntervalStates.rest;

            /// Update the current time to the rest time
            currentMicroSeconds = restSeconds! * secondsFactor;
          } else if (status == IntervalStates.rest) {
            /// Switch to the work state
            status = IntervalStates.work;

            /// Update the current time to the work time
            currentMicroSeconds = workSeconds! * secondsFactor;

            /// Since we have changed intervals, decrement the
            /// number of intervals at each work session
            numberOfWorkIntervals = numberOfWorkIntervals! - 1;
          }
          numberOfIntervals++;
        }

        /// There is still more time to deduct from the timer, so
        /// calculate if a sound effect should play
        else {
          /// Calculate half of the work time
          int halfWorkSeconds = ((workSeconds! * secondsFactor) / 2).round();

          /// Check if the halfway sound should play
          if (currentMicroSeconds! == halfWorkSeconds &&
              halfwaySoundID != -1 &&
              status == IntervalStates.work) {
            await pool.play(halfwaySoundID);
          }
          // Check if the 3, 2, 1 sound should play
          else if ((currentMicroSeconds! - 500000) == 3500000) {
            await pool.play(blankSoundID);
          } else if ((currentMicroSeconds! - 500000) == 2500000 ||
              (currentMicroSeconds! - 500000) == 1500000 ||
              (currentMicroSeconds! - 500000) == 500000) {
            if (countdownSoundID != -1) {
              await pool.play(countdownSoundID);
            }
          }

          /// Check which end sound should play
          else if (currentMicroSeconds! == 0) {
            /// The whole timer is done, play the final sound
            if (numberOfWorkIntervals == 0) {
              /// Audio player controller
              if (endSoundID != -1 && status != IntervalStates.complete) {
                await pool.play(endSoundID);
              }

              /// Switch to the complete state
              status = IntervalStates.complete;
            } else if (status == IntervalStates.work) {
              // Play the rest sound
              if (restSoundID != -1) {
                await pool.play(restSoundID);
              }
            } else if (status == IntervalStates.rest ||
                status == IntervalStates.start) {
              // Play the work sound
              if (workSoundID != -1) {
                await pool.play(workSoundID);
              }
            }
          } else if (currentMicroSeconds! <= -2000000) {
            await pool.release();
            service.stopSelf();
          } else {
            if (Platform.isIOS) {
              await pool.play(blankSoundID);
            }
          }
        }
      }

      String stringStatus = "";
      switch (status) {
        case IntervalStates.start:
          stringStatus = "start";
          break;
        case IntervalStates.work:
          stringStatus = "work";
          break;
        case IntervalStates.rest:
          stringStatus = "rest";
          break;
        case IntervalStates.complete:
          stringStatus = "complete";
          break;
        default:
          break;
      }

      int time = 0;
      if (currentMicroSeconds! > 0) {
        time = (currentMicroSeconds! / secondsFactor).round();
      }

      await preferences.setString("status", stringStatus);

      // Send data back to the UI
      service.invoke(
        'update',
        {
          "microSeconds": time,
          "status": stringStatus,
          "numberOfWorkIntervals": numberOfWorkIntervals,
          "numberOfIntervals": numberOfIntervals,
          "paused": paused
        },
      );
    });
  }

  static Future<int> loadSound(String sound, Soundpool pool) async {
    if (sound != "none") {
      return await rootBundle
          .load("packages/background_timer/lib/assets/audio/$sound.mp3")
          .then((ByteData soundData) {
        return pool.load(soundData);
      });
    }
    return -1;
  }
}
