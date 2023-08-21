import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:background_timer/background_timer_controller.dart';
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
    // return widget.build(context, 1
    //     // (_currentMicroSeconds / _secondsFactor).round(),
    //     );
    return StreamBuilder<Map<String, dynamic>?>(
      stream: FlutterBackgroundService().on('update'),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final service = FlutterBackgroundService();

        final data = snapshot.data!;
        _currentMicroSeconds = data["microSeconds"];

        // if (_timer?.isActive == true) {
        //   _timer!.cancel();

        //   widget.controller?.isCompleted = true;
        // }

        // if (_timer?.isActive == true) {
        //   _timer!.cancel();

        //   widget.controller?.isCompleted = true;
        // }

        if (!_onFinishedExecuted && _currentMicroSeconds == 0) {
          if (widget.onFinished != null) {
            widget.onFinished!();
            _onFinishedExecuted = true;
          }
          widget.controller?.isCompleted = true;
          // service.invoke("stopService");
        }

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
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

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

    Duration interval = const Duration(seconds: 1);

    const int secondsFactor = 1000000;

    SharedPreferences preferences = await SharedPreferences.getInstance();
    // await preferences.setInt("time", widget.seconds);
    final int? time = preferences.getInt('time');
    // await preferences.setInt("currentMicroSeconds", _currentMicroSeconds);
    int? currentMicroSeconds = preferences.getInt('currentMicroSeconds');
    // await preferences.setString("halfwaySound", widget.halfwaySound);
    final String? halfwaySound = preferences.getString('halfwaySound');
    // await preferences.setString("endSound", widget.endSound);
    final String? endSound = preferences.getString('endSound');
    // await preferences.setString("countdownSound", widget.countdownSound);
    final String? countdownSound = preferences.getString('countdownSound');
    // final bool? halfwayMark = preferences.getBool('halfwayMark');

    print('FLUTTER BACKGROUND SERVICE: ${currentMicroSeconds}');
    print('FLUTTER BACKGROUND SERVICE: ${interval.inMicroseconds}');
    print(
        'FLUTTER BACKGROUND SERVICE: ${(currentMicroSeconds! - interval.inMicroseconds)}');
    print('FLUTTER BACKGROUND SERVICE: ${((time! * secondsFactor) / 2)}');

    // if (_timer?.isActive == true) {
    //   _timer!.cancel();

    //   widget.controller?.isCompleted = true;
    // }

    //   if (_timer?.isActive == true) {
    //     _timer!.cancel();

    //     widget.controller?.isCompleted = true;
    //   }

    //   if (_currentMicroSeconds != 0) {
    //     _timer = Timer.periodic(
    //       widget.interval,
    //       (Timer timer) async {
    //         if (_currentMicroSeconds <= 0) {
    //           timer.cancel();

    //           if (widget.onFinished != null) {
    //             widget.onFinished!();
    //             this._onFinishedExecuted = true;
    //           }
    //           widget.controller?.isCompleted = true;
    //         } else {
    //           this._onFinishedExecuted = false;

    //           // print(widget.interval.inMicroseconds);
    //           // print(_currentMicroSeconds - widget.interval.inMicroseconds);
    //           // print((widget.seconds * _secondsFactor) / 2);
    //           // print(((widget.seconds * _secondsFactor) / 2) + 500000);
    //           // print("---");

    //           // Halfway
    //           if (widget.halfwayMark &&
    //               (_currentMicroSeconds - widget.interval.inMicroseconds) ==
    //                   ((widget.seconds * _secondsFactor) / 2) + 500000 &&
    //               widget.halfwaySound != 'none') {
    //             await player
    //                 .play(AssetSource('audio/${widget.halfwaySound}.mp3'));
    //           }
    //           // 3, 2, 1
    //           else if ((_currentMicroSeconds - widget.interval.inMicroseconds) ==
    //                   3500000 ||
    //               (_currentMicroSeconds - widget.interval.inMicroseconds) ==
    //                   2500000 ||
    //               (_currentMicroSeconds - widget.interval.inMicroseconds) ==
    //                   1500000) {
    //             if (widget.countdownSound != 'none') {
    //               await player
    //                   .play(AssetSource('audio/${widget.countdownSound}.mp3'));
    //             }
    //           }
    //           // End
    //           else if (_currentMicroSeconds - widget.interval.inMicroseconds ==
    //                   500000 &&
    //               widget.endSound != 'none') {
    //             await player.play(AssetSource('audio/${widget.endSound}.mp3'));
    //             service.invoke("stopService");
    //           }

    //           setState(() {
    //             _currentMicroSeconds =
    //                 _currentMicroSeconds - widget.interval.inMicroseconds;
    //           });
    //         }
    //       },
    //     );
    //   } else if (!this._onFinishedExecuted) {
    //     if (widget.onFinished != null) {
    //       widget.onFinished!();
    //       this._onFinishedExecuted = true;
    //     }
    //     widget.controller?.isCompleted = true;
    //   }
    // }

    // bring to foreground
    if (currentMicroSeconds != 0) {
      Timer.periodic(interval, (timer) async {
        final player = AudioPlayer();
        // await player.play(AssetSource('audio/countdown-beep.mp3'));

        print('FLUTTER BACKGROUND SERVICE: ${currentMicroSeconds}');
        // print('FLUTTER BACKGROUND SERVICE: ${interval.inMicroseconds}');
        // print(
        //     'FLUTTER BACKGROUND SERVICE: ${(currentMicroSeconds! - interval.inMicroseconds - 500000)}');
        // print('FLUTTER BACKGROUND SERVICE: ${((time! * secondsFactor) / 2)}');

        if (currentMicroSeconds! <= 0) {
          // Complete the timer
        } else {
          // Check halfway
          if ((currentMicroSeconds! - interval.inMicroseconds) ==
                  ((time! * secondsFactor) / 2) &&
              halfwaySound != 'none') {
            await player.play(AssetSource('audio/${halfwaySound}.mp3'));
            print('FLUTTER BACKGROUND SERVICE: HALFWAY');
          }
          // Check 3, 2, 1
          else if ((currentMicroSeconds! - 500000) == 3500000 ||
              (currentMicroSeconds! - 500000) == 2500000 ||
              (currentMicroSeconds! - 500000) == 1500000) {
            if (countdownSound != 'none') {
              await player.play(AssetSource('audio/${countdownSound}.mp3'));
            }
          }
          // Check end
          else if (currentMicroSeconds! == 1000000 && endSound != 'none') {
            await player.play(AssetSource('audio/${endSound}.mp3'));

            player.onPlayerStateChanged.listen(
              (it) {
                switch (it) {
                  case PlayerState.stopped:
                    service.stopSelf();
                    break;
                  case PlayerState.completed:
                    service.stopSelf();
                    break;
                  default:
                    break;
                }
              },
            );
            // service.invoke("stopService");
          }

          // setState(() {
          currentMicroSeconds =
              (currentMicroSeconds! - interval.inMicroseconds);
          // });
        }

        service.invoke(
          'update',
          {
            "seconds": (currentMicroSeconds! / secondsFactor).round(),
            "microSeconds": currentMicroSeconds,
            "isActive": true
            // "device": device,
          },
        );
      });
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
    _currentMicroSeconds = widget.seconds * _secondsFactor;
    _startTimer();

    // if (mounted) {
    //   setState(() {
    //     _currentMicroSeconds = widget.seconds * _secondsFactor;
    //   });

    //   _startTimer();
    // }
  }

  ///
  /// Start timer
  ///
  void _startTimer() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setInt("time", widget.seconds);
    await preferences.setInt("currentMicroSeconds", _currentMicroSeconds);
    await preferences.setString("halfwaySound", widget.halfwaySound);
    await preferences.setString("endSound", widget.endSound);
    await preferences.setString("countdownSound", widget.countdownSound);
    await preferences.setBool("halwayMark", widget.halfwayMark);
    await initializeService();
  }
}
