import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:ui';
import './lifecycle_event_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:background_timer/background_timer_controller.dart';
import 'package:audioplayers/audioplayers.dart';

///
/// Simple countdown timer.
///
class Countdown extends StatefulWidget {
  /// Length of the work interval
  final int workSeconds;

  /// Length of the rest interval
  final int restSeconds;

  /// Build method for the timer
  final Widget Function(BuildContext, int) build;

  /// Called when finished
  final Function? onFinished;

  /// Build interval
  final Duration interval;

  /// Controller
  final CountdownController? controller;

  /// Sound to play at session completion
  final String endSound;

  /// Sound for work interval
  final String workSound;

  /// Sound for rest interval
  final String restSound;

  /// Halfway mark sound
  final String halfwaySound;

  /// Countdown sound
  final String countdownSound;

  /// Intervals in the session
  final int numberOfIntervals;

  /// Current interval status
  final String status;

  ///
  /// Simple countdown timer
  ///
  const Countdown({
    Key? key,
    required this.workSeconds,
    required this.restSeconds,
    required this.numberOfIntervals,
    required this.build,
    this.status = 'start',
    this.endSound = 'horn',
    this.workSound = 'short-whistle',
    this.restSound = 'short-rest-beep',
    this.halfwaySound = 'short-halfway-beep',
    this.countdownSound = 'countdown-beep',
    this.interval = const Duration(microseconds: 500000),
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

  // Timer
  Timer? _timer;

  /// Internal control to indicate if the onFinished method was executed
  bool _onFinishedExecuted = false;

  // Current seconds
  late int _currentMicroSeconds;

  final player = AudioPlayer();

  @override
  void initState() {
    // _currentMicroSeconds = widget.seconds * _secondsFactor;
    // Get ready 10 seconds

    // WidgetsBinding.instance.addObserver(LifecycleEventHandler(
    //   detachedCallBack: widget.,
    //   resumeCallBack: FutureVoidCallback()
    // ));

    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _currentMicroSeconds = 10 * _secondsFactor;

    widget.controller?.setOnStart(_startTimer);
    widget.controller?.setOnPause(_onTimerPaused);
    widget.controller?.setOnResume(_onTimerResumed);
    widget.controller?.setOnRestart(_onTimerRestart);
    widget.controller?.isCompleted = false;

    if (widget.controller == null || widget.controller!.autoStart == true) {
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
    if (_timer?.isActive == true) {
      _timer?.cancel();
    }

    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final service = FlutterBackgroundService();

    if (state == AppLifecycleState.detached) {
      setState(() {
        print("--- Stopping ---");
        service.invoke("stopService");
        print("Should be stopped");
      });
      // print("--- Stopping ---");
      // service.invoke("stopService");
      // print("Should be stopped");
    }
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
    _currentMicroSeconds = widget.workSeconds * _secondsFactor;
    _startTimer();
  }

  ///
  /// Start timer
  ///
  void _startTimer() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setInt("workSeconds", widget.workSeconds);
    await preferences.setInt("restSeconds", widget.restSeconds);
    await preferences.setString("halfwaySound", widget.halfwaySound);
    await preferences.setString("endSound", widget.endSound);
    await preferences.setString("countdownSound", widget.countdownSound);
    await preferences.setString("workSound", widget.workSound);
    await preferences.setString("restSound", widget.restSound);
    await preferences.setInt("numberOfIntervals", widget.numberOfIntervals);
    await initializeService();
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

        return widget.build(
          context,
          (_currentMicroSeconds / _secondsFactor).round(),
        );
      },
    );
  }

  ///
  /// Initialize background service
  ///
  Future<void> initializeService() async {
    final service = FlutterBackgroundService();

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

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        // this will be executed when app is in foreground or background in separated isolate
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

    SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    final log = preferences.getStringList('log') ?? <String>[];
    log.add(DateTime.now().toIso8601String());
    await preferences.setStringList('log', log);

    return true;
  }

  ///
  ///
  ///
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // Only available for flutter 3.0.0 and later
    DartPluginRegistrant.ensureInitialized();

    // Countdown widget = Countdown(seconds: , build: build)

    // For flutter prior to version 3.0.0
    // We have to register the plugin manually

    // SharedPreferences preferences = await SharedPreferences.getInstance();
    // await preferences.setString("hello", "world");

    /// OPTIONAL when use custom notification
    // final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    // FlutterLocalNotificationsPlugin();

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

    Duration interval = const Duration(microseconds: 500000);

    const int secondsFactor = 1000000;

    SharedPreferences preferences = await SharedPreferences.getInstance();

    final String? halfwaySound = preferences.getString('halfwaySound');
    final String? endSound = preferences.getString('endSound');
    final String? countdownSound = preferences.getString('countdownSound');
    final String? workSound = preferences.getString('workSound');
    final String? restSound = preferences.getString('restSound');
    final int? workSeconds = preferences.getInt("workSeconds");
    final int? restSeconds = preferences.getInt("restSeconds");
    int? numberOfIntervals = preferences.getInt("numberOfIntervals");
    String? status = "start";

    final player = AudioPlayer();

    int? currentMicroSeconds = 10 * 1000000;

    Timer.periodic(interval, (timer) async {
      print('FLUTTER BACKGROUND SERVICE: ------------');
      print('FLUTTER BACKGROUND SERVICE: ${numberOfIntervals}');
      print('FLUTTER BACKGROUND SERVICE: ${status}');
      print('FLUTTER BACKGROUND SERVICE: ${currentMicroSeconds}');
      print('FLUTTER BACKGROUND SERVICE: ------------');

      if (status != "complete") {
        currentMicroSeconds = (currentMicroSeconds! - interval.inMicroseconds);
      }

      // if (numberOfIntervals! > 0) {
      // Check if time is greater than 0
      if (currentMicroSeconds! < 0) {
        // Timer done, check the status and decrement interval
        if (status == "start") {
          // Start work
          status = "work";
          currentMicroSeconds = workSeconds! * secondsFactor;
          // Decrement intervals after each work session
          numberOfIntervals = numberOfIntervals! - 1;
        } else if (status == "work") {
          // Start rest
          status = "rest";
          currentMicroSeconds = restSeconds! * secondsFactor;
          // print('FLUTTER BACKGROUND SERVICE: Setting to rest seconds now.');
          // print('FLUTTER BACKGROUND SERVICE: ${currentMicroSeconds}');
        } else if (status == "rest") {
          // Start work
          status = "work";
          currentMicroSeconds = workSeconds! * secondsFactor;
          // Decrement intervals after each work session
          numberOfIntervals = numberOfIntervals! - 1;
        }

        // currentMicroSeconds = preferences.getInt('currentMicroSeconds');
      } else {
        // Check sound
        //  Check halfway
        if ((currentMicroSeconds! == ((workSeconds! * secondsFactor) / 2)) &&
            halfwaySound != 'none' &&
            status == "work") {
          await player.play(AssetSource('audio/${halfwaySound}.mp3'));
          print('FLUTTER BACKGROUND SERVICE: HALFWAY');
        }
        // Check 3, 2, 1
        else if ((currentMicroSeconds! - 500000) == 2500000 ||
            (currentMicroSeconds! - 500000) == 1500000 ||
            (currentMicroSeconds! - 500000) == 500000) {
          if (countdownSound != 'none') {
            await player.play(AssetSource('audio/${countdownSound}.mp3'));
          }
        }
        // Check end
        else if (currentMicroSeconds! == 0 && endSound != 'none') {
          if (numberOfIntervals == 0) {
            // Play the end sound
            status = "complete";
            await player.play(AssetSource('audio/${endSound}.mp3'));
            // Stop the service
            print('FLUTTER BACKGROUND SERVICE: DONE');
            // service.stopSelf();
            player.onPlayerStateChanged.listen(
              (it) {
                switch (it) {
                  case PlayerState.stopped:
                    // service.stopSelf();
                    break;
                  case PlayerState.completed:
                    service.stopSelf();
                    // currentMicroSeconds = preferences.getInt('time');
                    break;
                  default:
                    break;
                }
              },
            );
          } else if (status == "rest" || status == "start") {
            // Play the work sound
            await player.play(AssetSource('audio/${workSound}.mp3'));
          } else if (status == "work") {
            // Play the rest sound
            await player.play(AssetSource('audio/${restSound}.mp3'));
          }
          // await player.play(AssetSource('audio/${endSound}.mp3'));
        }
      }
      // }

      // Send back data
      service.invoke(
        'update',
        {
          "seconds": (currentMicroSeconds! / secondsFactor).round(),
          "microSeconds": currentMicroSeconds,
          "status": status,
          "numberOfIntervals": numberOfIntervals
          // "device": device,
        },
      );

      // if (intervals == 0 && currentMicroSeconds! < 0) {
      //   // await player.play(AssetSource('audio/${endSound}.mp3'));

      //   player.onPlayerStateChanged.listen(
      //     (it) {
      //       switch (it) {
      //         case PlayerState.stopped:
      //           // service.stopSelf();
      //           break;
      //         case PlayerState.completed:
      //           service.stopSelf();
      //           // currentMicroSeconds = preferences.getInt('time');
      //           break;
      //         default:
      //           break;
      //       }
      //     },
      //   );
      //   // service.stopSelf();
      // }
    });
  }
}
