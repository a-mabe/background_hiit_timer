import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundpool/soundpool.dart';

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
  if (!sound.contains("none")) {
    return await rootBundle
        .load("packages/background_hiit_timer/lib/assets/audio/$sound.mp3")
        .then((ByteData soundData) {
      return pool.load(soundData);
    });
  }
  return -1;
}

Future playSound(
    int soundID, Soundpool pool, SharedPreferences preferences) async {
  if (soundID != 0) {
    await pool.setVolume(
        soundId: soundID,
        volume: ((preferences.getDouble('volume') ?? 80) / 100));
    await pool.play(soundID);
  }
}
