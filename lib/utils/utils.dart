import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:background_hiit_timer/utils/timer_config.dart';
import 'package:background_hiit_timer/utils/timer_state.dart';
import 'package:flutter/services.dart';
import 'package:openhiit_background_service/openhiit_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundpool/soundpool.dart';

import 'constants.dart';

Future<AudioSession> configureAudioSession() async {
  final session = await AudioSession.instance;

  await session.configure(const AudioSessionConfiguration(
    avAudioSessionCategory: AVAudioSessionCategory.playback,
    avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
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

  return session;
}

Future<int> loadSound(String sound, Soundpool pool) async {
  print("WWWWWWWWWWWWWWWWWWWWWWWWWW");
  print(sound);
  if (sound != "none" || sound != "None") {
    print("enter");
    return await rootBundle
        .load("packages/background_hiit_timer/lib/assets/audio/$sound.mp3")
        .then((ByteData soundData) {
      return pool.load(soundData);
    });
  }
  return -1;
}

void saveTimerPreferences(
    TimerConfig timerConfig, TimerState timerState) async {
  SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.setBool("pause", false);
  await preferences.setInt("workSeconds", timerConfig.exerciseTime);
  await preferences.setInt("restSeconds", timerConfig.restTime);
  await preferences.setInt("breakSeconds", timerConfig.breakTime);
  await preferences.setInt("getreadySeconds", timerConfig.getreadyTime);
  await preferences.setInt("warmupSeconds", timerConfig.warmupTime);
  await preferences.setInt("cooldownSeconds", timerConfig.cooldownTime);
  await preferences.setString("halfwaySound", timerConfig.halfwaySound);
  await preferences.setString("completeSound", timerConfig.completeSound);
  await preferences.setString("countdownSound", timerConfig.countdownSound);
  await preferences.setString("workSound", timerConfig.workSound);
  await preferences.setString("restSound", timerConfig.restSound);
  await preferences.setInt(
      "numberOfWorkIntervals", timerState.numberOfWorkIntervalsRemaining);
  await preferences.setInt("iterations", timerState.iterations);
}

Future<TimerConfig> loadTimerPreferences(SharedPreferences preferences) async {
  preferences.reload();

  TimerConfig timerConfig = TimerConfig(
      preferences.getInt("workSeconds")!,
      preferences.getInt("restSeconds")!,
      preferences.getInt("breakSeconds")!,
      preferences.getInt("getreadySeconds")!,
      preferences.getInt("warmupSeconds")!,
      preferences.getInt("cooldownSeconds")!,
      preferences.getInt("iterations")!,
      preferences.getString('workSound')!,
      preferences.getString('restSound')!,
      preferences.getString('halfwaySound')!,
      preferences.getString('completeSound')!,
      preferences.getString('countdownSound')!);

  return timerConfig;
}

Future playSound(
    int soundID, Soundpool pool, SharedPreferences preferences) async {
  print("soundid");
  print(soundID);
  if (soundID != -1) {
    await pool.setVolume(
        soundId: soundID,
        volume: ((preferences.getDouble('volume') ?? 80) / 100));
    await pool.play(soundID);
  }
}

Future<TimerState> playSoundEffectAndDetermineStatus(
    TimerConfig timerConfig,
    TimerState timerState,
    int secondsFactor,
    int currentMicroSeconds,
    int workSoundID,
    int restSoundID,
    int halfwaySoundID,
    int countdownSoundID,
    int completeSoundID,
    int blankSoundID,
    Soundpool pool,
    SharedPreferences preferences,
    ServiceInstance service) async {
  /// Calculate half of the work time
  int halfWorkSeconds =
      ((timerConfig.exerciseTime * secondsFactor) / 2).round();

  /// Check if the halfway sound should play
  if (currentMicroSeconds == halfWorkSeconds &&
      halfwaySoundID != -1 &&
      timerState.status == workStatus) {
    await pool.play(halfwaySoundID);
  }
  // Check if the 3, 2, 1 sound should play
  else if ((currentMicroSeconds - 500000) == 3500000) {
    await pool.play(blankSoundID);
  } else if ((currentMicroSeconds - 500000) == 2500000 ||
      (currentMicroSeconds - 500000) == 1500000 ||
      (currentMicroSeconds - 500000) == 500000) {
    await playSound(countdownSoundID, pool, preferences);
  }

  /// Check which end sound should play
  else if (currentMicroSeconds == 0) {
    if (timerState.status == cooldownStatus) {
      /// Play complete sound
      await playSound(completeSoundID, pool, preferences);

      /// Switch to the complete state
      timerState.status = completeStatus;
    }

    /// The whole iteration is done, play the final sound
    else if (timerState.numberOfWorkIntervalsRemaining == 0 &&
        timerState.status != completeStatus) {
      SharedPreferences preferences = await SharedPreferences.getInstance();

      if (timerState.status != cooldownStatus &&
          preferences.getInt('cooldownSeconds')! > 0 &&
          timerState.iterations == 0) {
        // timerState.iterations = timerState.iterations - 1;
        // Play the rest sound
        await playSound(restSoundID, pool, preferences);
        timerState = TimerState(
            false,
            preferences.getInt('numberOfWorkIntervals')!,
            timerState.currentOverallInterval + 1,
            preferences.getInt('cooldownSeconds')! * secondsFactor,
            "cooldown",
            timerState.iterations);
      } else {
        /// Play complete sound
        await playSound(completeSoundID, pool, preferences);

        /// Switch to the complete state
        timerState.status = completeStatus;

        /// Decrement the iterations if this was the last work interval
        if (timerState.numberOfWorkIntervalsRemaining == 0 &&
            timerState.iterations > 0) {
          timerState.iterations = timerState.iterations - 1;

          int breakSeconds = timerConfig.breakTime;
          if (breakSeconds > 0) {
            timerState = TimerState(
                false,
                preferences.getInt('numberOfWorkIntervals')!,
                timerState.currentOverallInterval + 1,
                breakSeconds * secondsFactor,
                "break",
                timerState.iterations);
          } else {
            timerState = TimerState(
                false,
                preferences.getInt('numberOfWorkIntervals')!,
                timerState.currentOverallInterval + 1,
                preferences.getInt('getreadySeconds')! * secondsFactor,
                "start",
                timerState.iterations);
          }
        }
      }
    } else if (timerState.status == workStatus ||
        timerState.status == warmupStatus) {
      // Play the rest sound
      await playSound(restSoundID, pool, preferences);
    } else if (timerState.status == restStatus ||
        timerState.status == startStatus ||
        timerState.status == breakStatus) {
      // Play the work sound
      await playSound(workSoundID, pool, preferences);
    }
  } else if (currentMicroSeconds < -500000) {
    await pool.release();
    service.stopSelf();
  } else {
    if (Platform.isIOS) {
      await pool.play(blankSoundID);
    }
  }

  return timerState;
}

Future<TimerState> workIntervalEnd(
    TimerState timerState, TimerConfig timerConfig) async {
  /// Switch to the rest state
  timerState.status = restStatus;

  /// Update the current time to the rest time
  timerState.currentMicroSeconds = timerConfig.restTime * secondsFactor;

  return timerState;
}

TimerState restIntervalEnd(TimerState timerState, TimerConfig timerConfig) {
  /// Switch to the work state
  timerState.status = workStatus;

  /// Update the current time to the work time
  timerState.currentMicroSeconds = timerConfig.exerciseTime * secondsFactor;

  /// Since we have changed intervals, decrement the
  /// number of intervals at each work session
  timerState.numberOfWorkIntervalsRemaining =
      timerState.numberOfWorkIntervalsRemaining - 1;

  return timerState;
}

TimerState startIntervalEnd(TimerState timerState, TimerConfig timerConfig) {
  if (timerConfig.warmupTime > 0 &&
      timerState.status != warmupStatus &&
      timerState.iterations == timerConfig.firstIteration) {
    timerState = TimerState(
        false,
        timerState.numberOfWorkIntervalsRemaining,
        timerState.currentOverallInterval,
        timerConfig.warmupTime * secondsFactor,
        "warmup",
        timerState.iterations);
  } else {
    /// Switch to the work state
    timerState.status = workStatus;

    /// Update the current time to the work time
    timerState.currentMicroSeconds = timerConfig.exerciseTime * secondsFactor;

    /// Since we have changed intervals, decrement the
    /// number of intervals at each work session
    timerState.numberOfWorkIntervalsRemaining =
        timerState.numberOfWorkIntervalsRemaining - 1;
  }

  return timerState;
}
