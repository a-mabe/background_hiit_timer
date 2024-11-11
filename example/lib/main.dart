import 'package:audio_session/audio_session.dart';
import 'package:background_hiit_timer/models/interval_type.dart';
import 'package:background_hiit_timer/models/timer_state.dart';
import 'package:example/controls/control_bar.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:background_hiit_timer/background_timer.dart';
import 'package:background_hiit_timer/background_timer_controller.dart';
import "package:flutter_driver/driver_extension.dart";

Future<void> main() async {
  enableFlutterDriverExtension();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Countdown Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Countdown'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;
  const MyHomePage({super.key, required this.title});

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  final CountdownController _controller = CountdownController(autoStart: true);
  List<int> listItems = [];
  List<int> removedItems = [];
  bool _paused = false;
  bool _changeVolume = false;
  double _volume = .8;
  late SharedPreferences prefs;

  final List<IntervalType> intervals = [
    IntervalType(
        id: "0",
        workoutId: "1",
        time: 5,
        name: "Get ready",
        color: 0,
        intervalIndex: 0,
        startSound: "",
        halfwaySound: "",
        countdownSound: "countdown-beep",
        endSound: ""),
    IntervalType(
        id: "1",
        workoutId: "1",
        time: 5,
        name: "Warmup",
        color: 0,
        intervalIndex: 1,
        startSound: "long-bell",
        halfwaySound: "",
        countdownSound: "countdown-beep",
        endSound: ""),
    IntervalType(
        id: "2",
        workoutId: "1",
        time: 5,
        name: "Work",
        color: 0,
        intervalIndex: 2,
        startSound: "long-bell",
        halfwaySound: "short-halfway-beep",
        countdownSound: "countdown-beep",
        endSound: ""),
    IntervalType(
        id: "3",
        workoutId: "1",
        time: 5,
        name: "Rest",
        color: 0,
        intervalIndex: 3,
        startSound: "long-rest-beep",
        halfwaySound: "",
        countdownSound: "countdown-beep",
        endSound: ""),
    IntervalType(
        id: "4",
        workoutId: "1",
        time: 5,
        name: "Cooldown",
        color: 0,
        intervalIndex: 4,
        startSound: "long-rest-beep",
        countdownSound: "countdown-beep",
        endSound: "horn",
        halfwaySound: ""),
  ];

  static const Map<String, Color> intervalColors = {
    "Work": Colors.green,
    "Rest": Colors.red,
    "Get ready": Colors.black,
    "Warmup": Colors.orange,
    "Cooldown": Colors.blue,
    "End": Colors.purple,
  };

  @override
  void initState() {
    super.initState();
    initializeAudioSession();
    loadPreferences();
    listItems = intervals.map((interval) => interval.intervalIndex).toList();
  }

  Future<void> initializeAudioSession() async {
    final session = await AudioSession.instance;

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
  }

  Future<void> loadPreferences() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {
      _volume = prefs.getDouble('volume') ?? .8;
      _changeVolume = prefs.getBool('changeVolume') ?? false;
    });
  }

  Future<void> toggleVolumeSlider() async {
    setState(() {
      _changeVolume = !_changeVolume;
    });
    await prefs.setBool('changeVolume', _changeVolume);
  }

  Future<void> togglePause() async {
    setState(() {
      _paused = !_paused;
    });
    _paused ? _controller.pause() : _controller.resume();
  }

  Color getBackgroundColor(String status) =>
      intervalColors[status] ?? const Color.fromARGB(255, 0, 225, 255);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Countdown(
        controller: _controller,
        intervals: intervals,
        onFinished: () {},
        build: (_, TimerState timerState) {
          while (listItems.length + timerState.currentInterval >
              intervals.length) {
            removedItems.add(listItems[0]);
            listItems.removeAt(0);
          }

          while (listItems.length + timerState.currentInterval <
              intervals.length) {
            listItems.insert(0, removedItems[removedItems.length - 1]);
            removedItems.removeAt(removedItems.length - 1);
          }

          return Container(
            color: getBackgroundColor(timerState.status),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(timerState.status,
                    style: const TextStyle(fontSize: 50, color: Colors.white)),
                Text(
                    (timerState.currentMicroSeconds /
                            const Duration(seconds: 1).inMicroseconds)
                        .round()
                        .toString(),
                    style: const TextStyle(fontSize: 100, color: Colors.white)),
                ControlBar(
                  onRestart: () => _controller.restart(),
                  paused: _paused,
                  changeVolume: _changeVolume,
                  volume: _volume,
                  onTogglePlayPause: togglePause,
                  onAdjustVolume: toggleVolumeSlider,
                  onSkipNext: _controller.skipNext,
                  onSkipPrevious: _controller.skipPrevious,
                ),
                SizedBox(
                  height: 220,
                  child: ListView.builder(
                    itemCount: listItems.length,
                    itemBuilder: (context, index) {
                      return Container(
                          color: const Color.fromARGB(64, 0, 0, 0),
                          child: ListTile(
                            title: Text(
                              intervals[listItems[index]].name,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ));
                    },
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}
