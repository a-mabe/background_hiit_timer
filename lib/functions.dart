import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:background_timer/config/timer_config.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundpool/soundpool.dart';

import 'config/constants.dart';

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
  if (sound != "none") {
    return await rootBundle
        .load("packages/background_timer/lib/assets/audio/$sound.mp3")
        .then((ByteData soundData) {
      return pool.load(soundData);
    });
  }
  return -1;
}

void saveTimerPreferences(TimerConfig config) async {
  SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.setBool("pause", false);
  await preferences.setInt("workSeconds", config.exerciseTime);
  await preferences.setInt("restSeconds", config.restTime);
  await preferences.setString("halfwaySound", config.halfwaySound);
  await preferences.setString("completeSound", config.completeSound);
  await preferences.setString("countdownSound", config.countdownSound);
  await preferences.setString("workSound", config.workSound);
  await preferences.setString("restSound", config.restSound);
  await preferences.setInt(
      "numberOfWorkIntervals", config.numberOfWorkIntervals);
}

Future<TimerConfig> loadTimerPreferences(SharedPreferences preferences) async {
  preferences.reload();

  TimerConfig timerConfig = TimerConfig(
      false,
      preferences.getInt("numberOfWorkIntervals")!,
      preferences.getInt("workSeconds")!,
      preferences.getInt("restSeconds")!,
      preferences.getString('workSound')!,
      preferences.getString('restSound')!,
      preferences.getString('halfwaySound')!,
      preferences.getString('completeSound')!,
      preferences.getString('countdownSound')!);

  return timerConfig;
}

Future playSound(int soundID, Soundpool pool) async {
  if (soundID != -1) {
    await pool.play(soundID);
  }
}

Future<String> determineSoundEffectAndStatus(
    TimerConfig config,
    int secondsFactor,
    int currentMicroSeconds,
    int workSoundID,
    int restSoundID,
    int halfwaySoundID,
    int countdownSoundID,
    int completeSoundID,
    int blankSoundID,
    String status,
    Soundpool pool,
    ServiceInstance service) async {
  /// Calculate half of the work time
  int halfWorkSeconds = ((config.exerciseTime * secondsFactor) / 2).round();

  /// Check if the halfway sound should play
  if (currentMicroSeconds! == halfWorkSeconds &&
      halfwaySoundID != -1 &&
      status == workStatus) {
    await pool.play(halfwaySoundID);
  }
  // Check if the 3, 2, 1 sound should play
  else if ((currentMicroSeconds! - 500000) == 3500000) {
    await pool.play(blankSoundID);
  } else if ((currentMicroSeconds! - 500000) == 2500000 ||
      (currentMicroSeconds! - 500000) == 1500000 ||
      (currentMicroSeconds! - 500000) == 500000) {
    await playSound(countdownSoundID, pool);
  }

  /// Check which end sound should play
  else if (currentMicroSeconds! == 0) {
    /// The whole timer is done, play the final sound
    if (config.numberOfWorkIntervals == 0 && status != completeStatus) {
      /// Play complete sound
      await playSound(completeSoundID, pool);

      /// Switch to the complete state
      status = completeStatus;
    } else if (status == workStatus) {
      // Play the rest sound
      await playSound(restSoundID, pool);
    } else if (status == restStatus || status == startStatus) {
      // Play the work sound
      await playSound(workSoundID, pool);
    }
  } else if (currentMicroSeconds <= -2000000) {
    await pool.release();
    service.stopSelf();
  } else {
    if (Platform.isIOS) {
      await pool.play(blankSoundID);
    }
  }

  return status;
}
