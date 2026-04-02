import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:background_hiit_timer/models/interval_type.dart';
import 'package:background_hiit_timer/models/timer_state.dart';
import 'package:background_hiit_timer/utils/constants.dart';
import 'package:background_hiit_timer/utils/log.dart';

MediaItem intervalToMediaItem(IntervalType interval) {
  return MediaItem(
    id: interval.id,
    title: interval.name,
    duration: Duration(seconds: interval.time),
    extras: interval.toMap(),
  );
}

IntervalType mediaItemToInterval(MediaItem item) {
  return IntervalType.fromMap(Map<String, dynamic>.from(item.extras ?? {}));
}

const String kActionRestart = 'restart';
const String kActionSkipNext = 'skipNext';
const String kActionSkipPrevious = 'skipPrevious';
const String kActionSetVolume = 'setVolume';

class HiitAudioHandler extends BaseAudioHandler {
  List<IntervalType> _intervals = [];
  late TimerState _timerState;
  Timer? _ticker;
  double _volume = 80.0;

  late final AudioPlayer _player;

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
    _broadcastState();
  }

  Future<void> startTimer(List<IntervalType> intervals, double volume) async {
    logger.d('HiitAudioHandler.startTimer — ${intervals.length} intervals');

    _stopTicker();
    _intervals = intervals;
    _volume = volume;

    final items = intervals.map(intervalToMediaItem).toList();
    queue.add(items);
    mediaItem.add(items.first);

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
    _startTicker();
  }

  Future<void> stopTimer() async {
    logger.d('HiitAudioHandler.stopTimer');
    _stopTicker();
    _timerState = TimerState.empty();
    _broadcastState();
    await stop();
  }

  @override
  Future<void> play() async {
    logger.d('play()');
    _timerState.paused = false;
    _broadcastState();
  }

  @override
  Future<void> pause() async {
    logger.d('pause()');
    _timerState.paused = true;
    _broadcastState();
  }

  @override
  Future<void> stop() async {
    logger.d('stop()');
    await stopTimer();
  }

  @override
  Future<void> skipToNext() async {
    logger.d('skipToNext()');
    _timerState.advanceToNextInterval(_intervals);
    _updateMediaItem();
    _broadcastState();
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
      _updateMediaItem();
      _broadcastState();
    }
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    switch (name) {
      case kActionRestart:
        logger.d('customAction: restart');
        _timerState.reset(_intervals);
        _updateMediaItem();
        _broadcastState();
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
      _timerState.status = "End";
      _broadcastState();
      return;
    }

    _timerState.currentMicroSeconds -= tickInterval.inMicroseconds;

    final int us = _timerState.currentMicroSeconds;
    final int nextIndex = intervalIndex + 1;

    if (countdownBeepMarks.contains(us)) {
      _playSound(_intervals[intervalIndex].countdownSound, _player, _volume);
    } else if (us == _timerState.intervalMicroSeconds ~/ 2) {
      _playSound(_intervals[intervalIndex].halfwaySound, _player, _volume);
    } else if (us == startSoundLookaheadMicros) {
      if (intervalIndex < _intervals.length - 1) {
        final String sound = _intervals[nextIndex].startSound;
        if (sound.isNotEmpty && sound != "none") {
          _playSound(sound, _player, _volume);
        } else {
          final String endSound = _intervals[intervalIndex].endSound;
          if (endSound.isNotEmpty && endSound != "none") {
            _playSound(endSound, _player, _volume);
          }
        }
      } else {
        _playSound(_intervals[intervalIndex].endSound, _player, _volume);
      }
    } else if (us == 0 && intervalIndex < _intervals.length - 1) {
      logger.d('Advancing to next interval');
      _timerState.advanceToNextInterval(_intervals);
      _updateMediaItem();
    } else if (us % 1000000 == 0 && us > startSoundLookaheadMicros) {
      _playSound(blankSoundFile, _player, _volume);
    }

    _broadcastState();
  }

  void _broadcastState() {
    final bool playing = !_timerState.paused;

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _timerState.status == "End"
            ? AudioProcessingState.completed
            : AudioProcessingState.ready,
        playing: playing,
        updatePosition: Duration(
          microseconds: _timerState.currentMicroSeconds,
        ),
        bufferedPosition: Duration.zero,
        speed: 1.0,
      ),
    );

    _timerStateController.add(_timerState);
  }

  void _updateMediaItem() {
    if (_intervals.isEmpty) return;
    final idx = _timerState.currentInterval.clamp(0, _intervals.length - 1);
    mediaItem.add(intervalToMediaItem(_intervals[idx]));
  }

  /// Play a named sound asset via [player] at [volume] (0.0 – 1.0).
  /// Sounds are expected at assets/audio/<sound>.mp3 inside the package.
  /// Silently skips if [sound] is empty or "none".
  Future<void> _playSound(
    String sound,
    AudioPlayer player,
    double volume,
  ) async {
    if (sound.isEmpty || sound == "none") {
      logger.d('Sound not set, skipping');
      return;
    }
    logger.d('Playing sound: $sound');
    try {
      await player.setVolume(volume / 100);
      await player.play(AssetSource("audio/$sound.mp3"));
    } catch (e) {
      logger.e('Error playing sound $sound: $e');
    }
  }
}
