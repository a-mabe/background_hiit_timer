import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:background_hiit_timer/utils/timer_config.dart';
import 'package:background_hiit_timer/utils/timer_state.dart';
import 'package:flutter/services.dart';
import 'package:openhiit_background_service/openhiit_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundpool/soundpool.dart';

import 'constants.dart';

// Future<audio_session.AudioSession> configureAudioSession() async {
//   final session = await audio_session.AudioSession.instance;

//   await session.configure(const audio_session.AudioSessionConfiguration(
//     avAudioSessionCategory: audio_session.AVAudioSessionCategory.playback,
//     avAudioSessionCategoryOptions:
//         audio_session.AVAudioSessionCategoryOptions.mixWithOthers,
//     avAudioSessionMode: audio_session.AVAudioSessionMode.defaultMode,
//     avAudioSessionRouteSharingPolicy:
//         audio_session.AVAudioSessionRouteSharingPolicy.defaultPolicy,
//     avAudioSessionSetActiveOptions:
//         audio_session.AVAudioSessionSetActiveOptions.none,
//     androidAudioAttributes: audio_session.AndroidAudioAttributes(
//       contentType: audio_session.AndroidAudioContentType.sonification,
//       flags: audio_session.AndroidAudioFlags.audibilityEnforced,
//       usage: audio_session.AndroidAudioUsage.notification,
//     ),
//     androidAudioFocusGainType: audio_session.AndroidAudioFocusGainType.gain,
//     androidWillPauseWhenDucked: true,
//   ));

//   return session;
// }

Future<int> loadSound(String sound, Soundpool pool) async {
  if (sound != "none") {
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

Future playSound(AudioPlayer player, String soundTitle,
    SharedPreferences preferences) async {
  if (soundTitle != "") {
    // await pool.play(soundID);
    preferences.getDouble('volume') == null
        ? await player.setVolume(1.0)
        : await player.setVolume((preferences.getDouble('volume')! / 100));
    await player.play(AssetSource("audio/$soundTitle.mp3"));
  }
}

Future<TimerState> playSoundEffectAndDetermineStatus(
    TimerConfig timerConfig,
    TimerState timerState,
    int secondsFactor,
    int currentMicroSeconds,
    ServiceInstance service,
    AudioPlayer player,
    SharedPreferences preferences) async {
  /// Calculate half of the work time
  int halfWorkSeconds =
      ((timerConfig.exerciseTime * secondsFactor) / 2).round();

  /// Check if the halfway sound should play
  if (currentMicroSeconds == halfWorkSeconds &&
      timerState.status == workStatus) {
    // await pool.play(halfwaySoundID);
    await playSound(player, timerConfig.halfwaySound, preferences);
  }
  // Check if the 3, 2, 1 sound should play
  else if ((currentMicroSeconds - 500000) == 3500000) {
    //await playSound(player, 'blank', preferences);
  } else if ((currentMicroSeconds - 500000) == 2500000 ||
      (currentMicroSeconds - 500000) == 1500000 ||
      (currentMicroSeconds - 500000) == 500000) {
    await playSound(player, timerConfig.countdownSound, preferences);
  }

  /// Check which end sound should play
  else if (currentMicroSeconds == 0) {
    if (timerState.status == cooldownStatus) {
      /// Play complete sound
      await playSound(player, timerConfig.completeSound, preferences);

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
        await playSound(player, timerConfig.restSound, preferences);
        timerState = TimerState(
            false,
            preferences.getInt('numberOfWorkIntervals')!,
            timerState.currentOverallInterval + 1,
            preferences.getInt('cooldownSeconds')! * secondsFactor,
            "cooldown",
            timerState.iterations);
      } else {
        /// Play complete sound
        await playSound(player, timerConfig.completeSound, preferences);

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
      await playSound(player, timerConfig.restSound, preferences);
    } else if (timerState.status == restStatus ||
        timerState.status == startStatus ||
        timerState.status == breakStatus) {
      // Play the work sound
      await playSound(player, timerConfig.workSound, preferences);
    }
  } else if (currentMicroSeconds < -500000) {
    service.stopSelf();
  } else {
    if (Platform.isIOS && currentMicroSeconds % 1000000 == 0) {
      // await pool.play(blankSoundID);
      print("BLANK");
      print(currentMicroSeconds);
      await playSound(player, 'blank', preferences);
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
