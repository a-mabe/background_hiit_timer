import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:background_timer/utils/timer_config.dart';
import 'package:background_timer/utils/timer_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:background_timer/background_timer_controller.dart';
import 'package:background_timer/background_timer_data.dart';
import 'package:soundpool/soundpool.dart';

import 'utils/constants.dart';
import 'utils/utils.dart';

///
/// Background service countdown interval timer.
///
class Countdown extends StatefulWidget {
  /// Number of seconds in the work interval.
  ///
  final int workSeconds;

  /// Number of seconds in the rest interval.
  ///
  final int restSeconds;

  /// Number of seconds in the break interval.
  ///
  final int breakSeconds;

  final int warmupSeconds;

  final int cooldownSeconds;

  /// Number of times to repeat the timer.
  ///
  final int iterations;

  /// Build method for the timer.
  ///
  final Widget Function(BuildContext, BackgroundTimerData) build;

  /// Called when the timer has finished all intervals.
  ///
  final Function? onFinished;

  /// Controller for the countdown timer.
  /// Allows external control and monitoring of the countdown timer.
  ///
  final CountdownController? controller;

  /// End sound - Sound to play at session completion.
  /// E.g. all intervals finished and timer complete.
  ///
  final String completeSound;

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

  ///
  /// Constructor
  ///
  const Countdown({
    Key? key,
    required this.workSeconds,
    required this.restSeconds,
    required this.numberOfWorkIntervals,
    required this.build,
    this.breakSeconds = 0,
    this.warmupSeconds = 0,
    this.cooldownSeconds = 0,
    this.iterations = 1,
    this.status = 'start',
    this.completeSound = 'horn',
    this.workSound = 'short-whistle',
    this.restSound = 'short-rest-beep',
    this.halfwaySound = 'short-halfway-beep',
    this.countdownSound = 'countdown-beep',
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
  /// Whether the timer is currently active.
  ///
  bool isActive = false;

  ///
  /// Initialize the timer.
  ///
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    widget.controller?.setOnStart(_startTimer);
    widget.controller?.setOnPause(_onTimerPaused);
    widget.controller?.setOnResume(_onTimerResumed);
    widget.controller?.setOnRestart(_onTimerRestart);
    widget.controller?.isCompleted = false;

    // Start the timer if autostart is enabled.
    if ((widget.controller == null) || (widget.controller!.autoStart == true)) {
      _startTimer();
    }
  }

  ///
  /// On dispose, stop the timer if active.
  ///
  @override
  void dispose() {
    /// Stop timer if active.
    if (isActive) {
      final service = FlutterBackgroundService();
      service.invoke("stopService");
    }

    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  ///
  /// On timer paused, updates the paused shared preference to true.
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
  /// On timer resumed, updates the paused shared preference to false.
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
  /// On timer restarted, stops the service and restarts the timer
  /// by running _startTimer.
  ///
  void _onTimerRestart() {
    final service = FlutterBackgroundService();
    service.invoke("stopService");
    _startTimer();
  }

  ///
  /// Start the timer.
  ///
  void _startTimer() async {
    // Set isActive to true to indicate the timer is active
    isActive = true;

    TimerConfig timerConfig = TimerConfig(
        widget.workSeconds,
        widget.restSeconds,
        widget.breakSeconds,
        widget.warmupSeconds,
        widget.cooldownSeconds,
        widget.iterations,
        widget.workSound,
        widget.restSound,
        widget.halfwaySound,
        widget.completeSound,
        widget.countdownSound);

    TimerState timerState = TimerState(
        false, widget.numberOfWorkIntervals, 0, 0, "start", widget.iterations);

    // Save timer settings to SharedPreferences
    saveTimerPreferences(timerConfig, timerState);

    // Initialize background service
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
          // Show loading indicator while waiting for data
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        // Grab the data from the snapshot
        final data = snapshot.data!;

        // Check if the timer has completed
        if (data["microSeconds"] == 0 &&
            widget.controller?.isCompleted == false) {
          // Invoke the onFinished callback if provided
          if (widget.onFinished != null) {
            widget.onFinished!();
          }
          widget.controller?.isCompleted = true;
        }
        // If not completed, ensure the isCompleted bool is set as such
        else if (data["microSeconds"] > 0) {
          widget.controller?.isCompleted = false;
        }

        /// Create object of data sent back from the timer
        BackgroundTimerData backgroundTimerData = BackgroundTimerData(
            data["microSeconds"],
            data["status"],
            data["numberOfWorkIntervals"],
            data["numberOfIntervals"],
            data["paused"]);

        // Return data and context to the UI
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
      'timer_foreground', // id
      'TIMER', // title
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

        notificationChannelId: 'timer_foreground',
        initialNotificationTitle: 'TIMER',
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

    // get SharedPreferences instance
    SharedPreferences preferences = await SharedPreferences.getInstance();

    // Define empty timer config
    TimerConfig timerConfig = await loadTimerPreferences(preferences);
    TimerState timerState = TimerState(
        false,
        preferences.getInt('numberOfWorkIntervals')!,
        0,
        10 * secondsFactor,
        "start",
        preferences.getInt('iterations')!);

    // Configure the audio session so that the timer does not
    // duck or pause other audio
    await configureAudioSession();

    // Configure the soundpool for the sound effects.
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

    int blankSoundID = await rootBundle
        .load("packages/background_timer/lib/assets/audio/blank.mp3")
        .then((ByteData soundData) {
      return pool.load(soundData);
    });

    int countdownSoundID = await loadSound(timerConfig.countdownSound, pool);
    int halfwaySoundID = await loadSound(timerConfig.halfwaySound, pool);
    int restSoundID = await loadSound(timerConfig.restSound, pool);
    int workSoundID = await loadSound(timerConfig.workSound, pool);
    int completeSoundID = await loadSound(timerConfig.completeSound, pool);

    Timer.periodic(interval, (timer) async {
      // Refresh shared preferences
      preferences.reload();

      // Grab the current pause state of the timer (true or false)
      timerState.paused = preferences.getBool('pause')!;

      // If the timer is not paused, keep counting down
      if (!timerState.paused) {
        /// If the timer has not been completed, then
        /// deduct a tenth of a second from the timer
        if (timerState.status != completeStatus) {
          timerState.currentMicroSeconds =
              (timerState.currentMicroSeconds - interval.inMicroseconds);
        }

        /// If there is no more time on the timer to deduct, then
        /// calculate the next action.
        if (timerState.currentMicroSeconds < -500000) {
          /// Determine timer status

          /// If the status was start or break
          if (timerState.status == startStatus ||
              timerState.status == breakStatus) {
            timerState = startIntervalEnd(timerState, timerConfig);
          }

          /// If the status was work
          else if (timerState.status == workStatus ||
              timerState.status == warmupStatus) {
            timerState = await workIntervalEnd(timerState, timerConfig);
          }

          /// If the status was rest
          else if (timerState.status == restStatus) {
            timerState = restIntervalEnd(timerState, timerConfig);
          }
          timerState.currentOverallInterval++;
        }

        /// There is still more time to deduct from the timer, so
        /// calculate if a sound effect should play
        else {
          timerState = await playSoundEffectAndDetermineStatus(
              timerConfig,
              timerState,
              secondsFactor,
              timerState.currentMicroSeconds,
              workSoundID,
              restSoundID,
              halfwaySoundID,
              countdownSoundID,
              completeSoundID,
              blankSoundID,
              pool,
              service);
        }
      }

      int time = 0;
      if (timerState.currentMicroSeconds > 0) {
        time = (timerState.currentMicroSeconds / secondsFactor).round();
      }

      // Send data back to the UI
      service.invoke(
        'update',
        {
          "microSeconds": time,
          "status": timerState.status,
          "numberOfWorkIntervals": timerState.numberOfWorkIntervalsRemaining,
          "numberOfIntervals": timerState.currentOverallInterval,
          "paused": timerState.paused
        },
      );
    });
  }
}
