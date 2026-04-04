import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:background_hiit_timer/models/interval_type.dart';
import 'package:background_hiit_timer/models/timer_state.dart';
import 'package:background_hiit_timer/utils/constants.dart';
import 'package:background_hiit_timer/utils/log.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const String kActionRestart = 'restart';
const String kActionSkipNext = 'skipNext';
const String kActionSkipPrevious = 'skipPrevious';
const String kActionSetVolume = 'setVolume';

// Notification action IDs
const String _kNotifActionPause = 'pause';
const String _kNotifActionPlay = 'play';
const String _kNotifActionSkipNext = 'skip_next';
const String _kNotifActionSkipPrev = 'skip_prev';
const String _kNotifCategoryPlaying = 'hiit_playing';
const String _kNotifCategoryPaused = 'hiit_paused';

const int _kNotificationId = 888;
const String _kChannelId = 'hiit_timer';
const String _kChannelName = 'HIIT Timer';

// Top-level — required by flutter_local_notifications for background actions
@pragma('vm:entry-point')
void _onBackgroundNotificationAction(NotificationResponse response) {
  // Background notification taps are handled by the OS routing the action
  // back through the audio service — no direct handler access needed here
}

class HiitAudioHandler extends BaseAudioHandler {
  List<IntervalType> _intervals = [];
  late TimerState _timerState;
  Timer? _ticker;
  double _volume = 80.0;
  int _lastNotifiedSecond = -1;

  late final AudioPlayer _player;
  final _notifications = FlutterLocalNotificationsPlugin();

  final _timerStateController = StreamController<TimerState>.broadcast();
  Stream<TimerState> get timerStateStream => _timerStateController.stream;

  HiitAudioHandler() {
    _player = AudioPlayer();
    _player.audioCache = AudioCache(
      prefix: 'packages/background_hiit_timer/assets/',
    );
    _player.setPlayerMode(PlayerMode.lowLatency);

    AudioPlayer.global.setAudioContext(
      AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
    );

    _timerState = TimerState.empty();
    _initNotifications();
    _broadcastState();
  }

  // ── Notifications ──────────────────────────────────────────────────────────

  Future<void> _initNotifications() async {
    // iOS: register action categories up front
    final List<DarwinNotificationCategory> iosCategories = [
      DarwinNotificationCategory(
        _kNotifCategoryPlaying,
        actions: [
          DarwinNotificationAction.plain(_kNotifActionSkipPrev, '⏮'),
          DarwinNotificationAction.plain(_kNotifActionPause, '⏸'),
          DarwinNotificationAction.plain(_kNotifActionSkipNext, '⏭'),
        ],
      ),
      DarwinNotificationCategory(
        _kNotifCategoryPaused,
        actions: [
          DarwinNotificationAction.plain(_kNotifActionSkipPrev, '⏮'),
          DarwinNotificationAction.plain(_kNotifActionPlay, '▶'),
          DarwinNotificationAction.plain(_kNotifActionSkipNext, '⏭'),
        ],
      ),
    ];

    const androidSettings = AndroidInitializationSettings(
      'ic_launcher',
    );

    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: iosCategories,
    );

    final settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundNotificationAction,
    );

    // Create Android notification channel
    if (Platform.isAndroid) {
      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _kChannelId,
              _kChannelName,
              importance: Importance.low,
              playSound: false,
              enableVibration: false,
            ),
          );
    }

    // Request iOS permission
    if (Platform.isIOS) {
      await _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: false,
            sound: false,
          );
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    logger.d('Notification action: ${response.actionId}');
    switch (response.actionId) {
      case _kNotifActionPause:
        pause();
        break;
      case _kNotifActionPlay:
        play();
        break;
      case _kNotifActionSkipNext:
        skipToNext();
        break;
      case _kNotifActionSkipPrev:
        skipToPrevious();
        break;
    }
  }

  Future<void> _showNotification() async {
    if (_timerState.status == 'End' || _timerState.status == '') return;

    logger.d(
        '_showNotification — ${_timerState.status}, ${_timerState.currentMicroSeconds}');

    final bool paused = _timerState.paused;
    final int seconds =
        (_timerState.currentMicroSeconds / secondsFactor).ceil();

    final androidDetails = AndroidNotificationDetails(
      _kChannelId,
      _kChannelName,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      playSound: false,
      enableVibration: false,
      onlyAlertOnce: true,
      actions: [
        const AndroidNotificationAction(_kNotifActionSkipPrev, '⏮'),
        AndroidNotificationAction(
          paused ? _kNotifActionPlay : _kNotifActionPause,
          paused ? '▶' : '⏸',
        ),
        const AndroidNotificationAction(_kNotifActionSkipNext, '⏭'),
      ],
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: false,
      interruptionLevel: InterruptionLevel.passive,
      categoryIdentifier:
          paused ? _kNotifCategoryPaused : _kNotifCategoryPlaying,
    );

    await _notifications.show(
      id: _kNotificationId,
      payload: _timerState.status,
      title: '$seconds seconds remaining',
      notificationDetails:
          NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  Future<void> _cancelNotification() async {
    await _notifications.cancel(id: _kNotificationId);
  }

  // ── Timer ──────────────────────────────────────────────────────────────────

  Future<void> startTimer(List<IntervalType> intervals, double volume) async {
    logger.d('HiitAudioHandler.startTimer — ${intervals.length} intervals');

    _stopTicker();
    _intervals = intervals;
    _volume = volume;
    _lastNotifiedSecond = -1;

    _timerState = TimerState(
      false,
      intervals[0].name,
      0,
      intervals[0].time * secondsFactor,
      intervals[0].time * secondsFactor,
      volume,
      false,
    );

    _broadcastState();
    _showNotification();
    _startTicker();
  }

  @override
  Future<void> stop() async {
    logger.d('stop()');
    _stopTicker();
    _timerState = TimerState.empty();
    await _cancelNotification();
    _broadcastState();
    await super.stop();
  }

  @override
  Future<void> play() async {
    logger.d('play()');
    _timerState.paused = false;
    _broadcastState();
    _showNotification();
  }

  @override
  Future<void> pause() async {
    logger.d('pause()');
    _timerState.paused = true;
    _broadcastState();
    _showNotification();
  }

  Future<void> stopTimer() async {
    logger.d('HiitAudioHandler.stopTimer');
    await stop();
  }

  @override
  Future<void> skipToNext() async {
    logger.d('skipToNext()');
    _timerState.advanceToNextInterval(_intervals);
    _lastNotifiedSecond = -1;
    _broadcastState();
    _showNotification();
  }

  @override
  Future<void> skipToPrevious() async {
    logger.d('skipToPrevious()');
    if (_timerState.currentInterval > 0) {
      _timerState.currentInterval--;
      _timerState.currentMicroSeconds =
          _intervals[_timerState.currentInterval].time * secondsFactor;
      _timerState.intervalMicroSeconds =
          _intervals[_timerState.currentInterval].time * secondsFactor;
      _timerState.status = _intervals[_timerState.currentInterval].name;
      _lastNotifiedSecond = -1;
      _broadcastState();
      _showNotification();
    }
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    switch (name) {
      case kActionRestart:
        logger.d('customAction: restart');
        _timerState.reset(_intervals);
        _lastNotifiedSecond = -1;
        _broadcastState();
        _showNotification();
        break;

      case kActionSetVolume:
        final v = (extras?['volume'] as num?)?.toDouble();
        if (v != null) {
          _volume = v;
          _timerState.volume = v;
          _broadcastState();
        }
        break;
    }
  }

  void _startTicker() {
    _ticker = Timer.periodic(tickInterval, (_) => _tick());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _tick() {
    if (_timerState.paused) {
      _broadcastState();
      return;
    }

    final int intervalIndex = _timerState.currentInterval;

    if (_timerState.currentMicroSeconds <= 0) {
      _timerState.status = 'End';
      _cancelNotification();
      _broadcastState();
      return;
    }

    _timerState.currentMicroSeconds -= tickInterval.inMicroseconds;

    final int us = _timerState.currentMicroSeconds;
    final int nextIndex = intervalIndex + 1;

    // Update notification once per second
    final int currentSecond = (us / secondsFactor).ceil();
    if (currentSecond != _lastNotifiedSecond) {
      _lastNotifiedSecond = currentSecond;
      _showNotification();
    }

    if (countdownBeepMarks.contains(us)) {
      _playSound(_intervals[intervalIndex].countdownSound, _player, _volume);
    } else if (us == _timerState.intervalMicroSeconds ~/ 2) {
      _playSound(_intervals[intervalIndex].halfwaySound, _player, _volume);
    } else if (us == startSoundLookaheadMicros) {
      if (intervalIndex < _intervals.length - 1) {
        final String sound = _intervals[nextIndex].startSound;
        if (sound.isNotEmpty && sound != 'none') {
          _playSound(sound, _player, _volume);
        } else {
          final String endSound = _intervals[intervalIndex].endSound;
          if (endSound.isNotEmpty && endSound != 'none') {
            _playSound(endSound, _player, _volume);
          }
        }
      } else {
        _playSound(_intervals[intervalIndex].endSound, _player, _volume);
      }
    } else if (us == 0 && intervalIndex < _intervals.length - 1) {
      logger.d('Advancing to next interval');
      _timerState.advanceToNextInterval(_intervals);
      _lastNotifiedSecond = -1;
    } else if (us % 1000000 == 0 && us > startSoundLookaheadMicros) {
      _playSound(blankSoundFile, _player, _volume);
    }

    _broadcastState();
  }

  void _broadcastState() {
    logger.d(
        '_broadcastState — playing: ${!_timerState.paused}, status: ${_timerState.status}');

    playbackState.add(
      playbackState.value.copyWith(
        processingState: _timerState.status == 'End'
            ? AudioProcessingState.completed
            : AudioProcessingState.ready,
        playing: !_timerState.paused,
      ),
    );

    _timerStateController.add(_timerState);
  }

  Future<void> _playSound(
    String sound,
    AudioPlayer player,
    double volume,
  ) async {
    if (sound.isEmpty || sound == 'none') {
      logger.d('Sound not set, skipping');
      return;
    }
    logger.d('Playing sound: $sound');
    try {
      await player.setVolume(volume / 100);
      await player.play(AssetSource('audio/$sound.mp3'));
    } catch (e) {
      logger.e('Error playing sound $sound: $e');
    }
  }
}

// import 'dart:async';

// import 'package:audio_service/audio_service.dart';
// import 'package:audioplayers/audioplayers.dart';
// import 'package:background_hiit_timer/models/interval_type.dart';
// import 'package:background_hiit_timer/models/timer_state.dart';
// import 'package:background_hiit_timer/utils/constants.dart';
// import 'package:background_hiit_timer/utils/log.dart';

// const String kActionRestart = 'restart';
// const String kActionSkipNext = 'skipNext';
// const String kActionSkipPrevious = 'skipPrevious';
// const String kActionSetVolume = 'setVolume';

// class HiitAudioHandler extends BaseAudioHandler {
//   List<IntervalType> _intervals = [];
//   late TimerState _timerState;
//   Timer? _ticker;
//   double _volume = 80.0;

//   late final AudioPlayer _player;

//   final _timerStateController = StreamController<TimerState>.broadcast();
//   Stream<TimerState> get timerStateStream => _timerStateController.stream;

//   HiitAudioHandler() {
//     _player = AudioPlayer();
//     _player.audioCache = AudioCache(
//       prefix: 'packages/background_hiit_timer/assets/',
//     );
//     _player.setPlayerMode(PlayerMode.lowLatency);

//     AudioPlayer.global.setAudioContext(
//       AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
//     );

//     _timerState = TimerState.empty();
//     _broadcastState();
//   }

//   Future<void> startTimer(List<IntervalType> intervals, double volume) async {
//     logger.d('HiitAudioHandler.startTimer — ${intervals.length} intervals');

//     _stopTicker();
//     _intervals = intervals;
//     _volume = volume;

//     _timerState = TimerState(
//       false,
//       intervals[0].name,
//       0,
//       intervals[0].time * secondsFactor,
//       intervals[0].time * secondsFactor,
//       volume,
//       false,
//     );

//     _broadcastState();
//     _startTicker();
//   }

//   @override
//   Future<void> stop() async {
//     logger.d('stop()');
//     _stopTicker();
//     _timerState = TimerState.empty();
//     _broadcastState();
//     await super.stop();
//   }

//   @override
//   Future<void> play() async {
//     logger.d('play()');
//     _timerState.paused = false;
//     _broadcastState();
//   }

//   @override
//   Future<void> pause() async {
//     logger.d('pause()');
//     _timerState.paused = true;
//     _broadcastState();
//   }

//   Future<void> stopTimer() async {
//     logger.d('HiitAudioHandler.stopTimer');
//     await stop();
//   }

//   @override
//   Future<void> skipToNext() async {
//     logger.d('skipToNext()');
//     _timerState.advanceToNextInterval(_intervals);
//     _broadcastState();
//   }

//   @override
//   Future<void> skipToPrevious() async {
//     logger.d('skipToPrevious()');
//     if (_timerState.currentInterval > 0) {
//       _timerState.currentInterval--;
//       _timerState.currentMicroSeconds =
//           _intervals[_timerState.currentInterval].time * secondsFactor;
//       _timerState.intervalMicroSeconds =
//           _intervals[_timerState.currentInterval].time * secondsFactor;
//       _timerState.status = _intervals[_timerState.currentInterval].name;
//       _broadcastState();
//     }
//   }

//   @override
//   Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
//     switch (name) {
//       case kActionRestart:
//         logger.d('customAction: restart');
//         _timerState.reset(_intervals);
//         _broadcastState();
//         break;

//       case kActionSetVolume:
//         final v = (extras?['volume'] as num?)?.toDouble();
//         if (v != null) {
//           _volume = v;
//           _timerState.volume = v;
//           _broadcastState();
//         }
//         break;
//     }
//   }

//   void _startTicker() {
//     _ticker = Timer.periodic(tickInterval, (_) => _tick());
//   }

//   void _stopTicker() {
//     _ticker?.cancel();
//     _ticker = null;
//   }

//   void _tick() {
//     if (_timerState.paused) {
//       _broadcastState();
//       return;
//     }

//     final int intervalIndex = _timerState.currentInterval;

//     if (_timerState.currentMicroSeconds <= 0) {
//       _timerState.status = "End";
//       _broadcastState();
//       return;
//     }

//     _timerState.currentMicroSeconds -= tickInterval.inMicroseconds;

//     final int us = _timerState.currentMicroSeconds;
//     final int nextIndex = intervalIndex + 1;

//     if (countdownBeepMarks.contains(us)) {
//       _playSound(_intervals[intervalIndex].countdownSound, _player, _volume);
//     } else if (us == _timerState.intervalMicroSeconds ~/ 2) {
//       _playSound(_intervals[intervalIndex].halfwaySound, _player, _volume);
//     } else if (us == startSoundLookaheadMicros) {
//       if (intervalIndex < _intervals.length - 1) {
//         final String sound = _intervals[nextIndex].startSound;
//         if (sound.isNotEmpty && sound != "none") {
//           _playSound(sound, _player, _volume);
//         } else {
//           final String endSound = _intervals[intervalIndex].endSound;
//           if (endSound.isNotEmpty && endSound != "none") {
//             _playSound(endSound, _player, _volume);
//           }
//         }
//       } else {
//         _playSound(_intervals[intervalIndex].endSound, _player, _volume);
//       }
//     } else if (us == 0 && intervalIndex < _intervals.length - 1) {
//       logger.d('Advancing to next interval');
//       _timerState.advanceToNextInterval(_intervals);
//     } else if (us % 1000000 == 0 && us > startSoundLookaheadMicros) {
//       _playSound(blankSoundFile, _player, _volume);
//     }

//     _broadcastState();
//   }

//   void _broadcastState() {
//     final bool playing = !_timerState.paused;

//     logger.d(
//         '_broadcastState — playing: $playing, status: ${_timerState.status}');

//     playbackState.add(
//       playbackState.value.copyWith(
//         processingState: _timerState.status == "End"
//             ? AudioProcessingState.completed
//             : AudioProcessingState.ready,
//         playing: !_timerState.paused,
//       ),
//     );

//     _timerStateController.add(_timerState);
//   }

//   /// Play a named sound asset via [player] at [volume] (0.0 – 1.0).
//   /// Sounds are expected at assets/audio/<sound>.mp3 inside the package.
//   /// Silently skips if [sound] is empty or "none".
//   Future<void> _playSound(
//     String sound,
//     AudioPlayer player,
//     double volume,
//   ) async {
//     if (sound.isEmpty || sound == "none") {
//       logger.d('Sound not set, skipping');
//       return;
//     }
//     logger.d('Playing sound: $sound');
//     try {
//       await player.setVolume(volume / 100);
//       await player.play(AssetSource("audio/$sound.mp3"));
//     } catch (e) {
//       logger.e('Error playing sound $sound: $e');
//     }
//   }
// }
