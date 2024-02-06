import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:background_timer/background_timer.dart';
import 'package:background_timer/background_timer_controller.dart';
import 'package:background_timer/background_timer_data.dart';

void main() => runApp(const MyApp());

///
/// Test app
///
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Countdown Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(
        title: 'Flutter Demo Countdown',
      ),
    );
  }
}

///
/// Home page
///
class MyHomePage extends StatefulWidget {
  ///
  /// AppBar title
  ///
  final String title;

  /// Home page
  const MyHomePage({
    Key? key,
    required this.title,
  }) : super(key: key);

  @override
  MyHomePageState createState() => MyHomePageState();
}

///
/// Page state
///
class MyHomePageState extends State<MyHomePage> {
  // Controller
  final CountdownController _controller = CountdownController(autoStart: true);

  @override
  initState() {
    super.initState();
    init();
  }

  void init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.ambient,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.mixWithOthers,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      avAudioSessionRouteSharingPolicy:
          AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.voiceCommunication,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ));
  }

  Color backgroundColor(String status) {
    switch (status) {
      case "work":
        return Colors.green;
      case "rest":
        return Colors.red;
      case "start":
        return Colors.black;
      case "break":
        return Colors.teal;
      case "warmup":
        return Colors.orange;
      case "cooldown":
        return Colors.blue;
      default:
        return const Color.fromARGB(255, 0, 225, 255);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Countdown(
          controller: _controller,
          workSeconds: 4,
          restSeconds: 2,
          getreadySeconds: 7,
          breakSeconds: 5,
          warmupSeconds: 10,
          cooldownSeconds: 10,
          numberOfWorkIntervals: 1,
          iterations: 1,
          onFinished: () {},
          build: (_, BackgroundTimerData timerData) {
            return Container(
              color: backgroundColor(timerData.status),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Text(
                    timerData.status,
                    style: const TextStyle(fontSize: 50, color: Colors.white),
                  ),
                  Text(
                    timerData.currentMicroSeconds.toString(),
                    style: const TextStyle(fontSize: 100, color: Colors.white),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        // Start
                        ElevatedButton(
                          child: const Text('Start'),
                          onPressed: () {
                            _controller.start();
                          },
                        ),
                        // Pause
                        ElevatedButton(
                          child: const Text('Pause'),
                          onPressed: () {
                            _controller.pause();
                          },
                        ),
                        // Resume
                        ElevatedButton(
                          child: const Text('Resume'),
                          onPressed: () {
                            _controller.resume();
                          },
                        ),
                        // Stop
                        ElevatedButton(
                          child: const Text('Restart'),
                          onPressed: () {
                            _controller.restart();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
    );
  }
}
