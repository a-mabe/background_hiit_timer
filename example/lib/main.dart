import 'package:background_hiit_timer/countdown.dart';
import 'package:background_hiit_timer/countdown_controller.dart';
import 'package:background_hiit_timer/hiit_audio_handler.dart';
import 'package:background_hiit_timer/models/interval_type.dart';
import 'package:background_hiit_timer/models/timer_state.dart';
import 'package:example/controls/control_bar.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Countdown Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
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

  bool _paused = false;
  bool _changeVolume = false;
  double _volume = 0.8; // 0.0–1.0 for the slider

  List<int> listItems = [];
  List<int> removedItems = [];

  // ── interval list ────────────────────────────────────────────────────────

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
      endSound: "",
    ),
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
      endSound: "",
    ),
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
      endSound: "",
    ),
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
      endSound: "",
    ),
    IntervalType(
      id: "4",
      workoutId: "1",
      time: 5,
      name: "Cooldown",
      color: 0,
      intervalIndex: 4,
      startSound: "long-rest-beep",
      halfwaySound: "",
      countdownSound: "countdown-beep",
      endSound: "horn",
    ),
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
    listItems = intervals.map((i) => i.intervalIndex).toList();
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  Color getBackgroundColor(String status) =>
      intervalColors[status] ?? const Color.fromARGB(255, 0, 225, 255);

  void _togglePause() {
    setState(() => _paused = !_paused);
    _paused ? _controller.pause() : _controller.resume();
  }

  void _toggleVolumeSlider() {
    setState(() => _changeVolume = !_changeVolume);
  }

  /// Push the new volume into the running handler so it takes effect
  /// immediately without restarting the timer.
  void _onVolumeChanged(double value) {
    setState(() => _volume = value);
    // Convert 0–1 slider value to the 0–100 scale the handler uses.
    CountdownState.handler?.customAction(kActionSetVolume, {
      'volume': value * 100,
    });
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Countdown(
        controller: _controller,
        intervals: intervals,
        onFinished: () {},
        build: (_, TimerState timerState) {
          // Keep the interval queue list in sync with the current position.
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
                Text(
                  timerState.status,
                  style: const TextStyle(fontSize: 50, color: Colors.white),
                ),
                Text(
                  (timerState.currentMicroSeconds /
                          const Duration(seconds: 1).inMicroseconds)
                      .round()
                      .toString(),
                  style: const TextStyle(fontSize: 100, color: Colors.white),
                ),
                ControlBar(
                  paused: _paused,
                  changeVolume: _changeVolume,
                  volume: _volume,
                  onRestart: _controller.restart,
                  onTogglePlayPause: _togglePause,
                  onAdjustVolume: _toggleVolumeSlider,
                  onSkipNext: _controller.skipNext,
                  onSkipPrevious: _controller.skipPrevious,
                  onVolumeChanged: _onVolumeChanged,
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
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
